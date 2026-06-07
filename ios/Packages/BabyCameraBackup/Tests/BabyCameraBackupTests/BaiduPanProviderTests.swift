import XCTest
@testable import BabyCameraBackup

final class BaiduPanProviderTests: XCTestCase {
    private var oauth: StubBaiduPanOAuthService!
    private var openAPI: MockBaiduPanOpenAPIClient!
    private var tokenStore: InMemoryBaiduPanTokenStore!
    private var ledger: InMemoryBaiduPanUploadLedger!
    private var clock: ControllableBackupClock!
    private var provider: BaiduPanProvider!

    override func setUp() {
        super.setUp()
        oauth = StubBaiduPanOAuthService()
        openAPI = MockBaiduPanOpenAPIClient()
        tokenStore = InMemoryBaiduPanTokenStore()
        ledger = InMemoryBaiduPanUploadLedger()
        clock = ControllableBackupClock()
        provider = BaiduPanProvider(
            oauth: oauth,
            openAPI: openAPI,
            tokenStore: tokenStore,
            ledger: ledger,
            clock: clock
        )
    }

    func testKindIsBaiduPan() {
        XCTAssertEqual(provider.kind, .baiduPan)
        XCTAssertEqual(BackupKind.baiduPan.apiKindValue, "baidu_pan")
    }

    func testAuthorizeStoresCredentialsInTokenStore() async throws {
        try await provider.authorize()

        let stored = tokenStore.load()
        XCTAssertEqual(stored?.accessToken, "baidu-access-stub")
        XCTAssertEqual(stored?.refreshToken, "baidu-refresh-stub")
        XCTAssertEqual(stored?.providerAccountId, "baidu-user-stub")
    }

    func testAuthorizeSkipsOAuthWhenValidTokenExists() async throws {
        tokenStore.save(
            BaiduPanCredentials(
                accessToken: "cached-token",
                refreshToken: "cached-refresh",
                expiresAt: Date(timeIntervalSinceNow: 3600)
            )
        )

        try await provider.authorize()
        XCTAssertEqual(tokenStore.load()?.accessToken, "cached-token")
    }

    func testAuthorizeThrowsWhenOAuthFails() async {
        oauth.shouldFail = true

        do {
            try await provider.authorize()
            XCTFail("Expected authorizationFailed")
        } catch let error as BaiduPanProviderError {
            if case let .authorizationFailed(message) = error {
                XCTAssertEqual(message, "oauth cancelled")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testQuotaUsesOpenAPI() async throws {
        openAPI.quotaResult = BaiduPanQuotaInfo(usedBytes: 1_024, totalBytes: 2_048)
        tokenStore.save(BaiduPanCredentials(accessToken: "token"))

        let quota = try await provider.quota()

        XCTAssertEqual(quota.usedBytes, 1_024)
        XCTAssertEqual(quota.totalBytes, 2_048)
    }

    func testUploadWritesRemotePathAndRecordsLedger() async throws {
        let fileURL = try makeTemporaryFile(named: "photo.heic", contents: Data([0x01, 0x02, 0x03]))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        openAPI.uploadResult = BaiduPanUploadResult(fsId: 42, remotePath: "ignored")
        tokenStore.save(BaiduPanCredentials(accessToken: "token"))

        let item = BackupItem(
            photoId: "p1",
            sha256: "hash-a",
            filePath: fileURL.path,
            mimeType: "image/heic",
            byteSize: 3,
            updatedAt: 100
        )

        clock.advance(bySeconds: 0)
        let receipt = try await provider.upload(item)

        XCTAssertEqual(openAPI.uploadedPaths.count, 1)
        XCTAssertEqual(
            openAPI.uploadedPaths[0],
            "/apps/babycamera/backups/p1_hash-a.heic"
        )
        XCTAssertEqual(receipt.remoteId, "42")
        XCTAssertEqual(receipt.sha256, "hash-a")
        XCTAssertEqual(receipt.uploadedAt, clock.nowUnixMillis())

        let page = try await provider.list(after: nil)
        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items[0].sha256, "hash-a")
    }

    func testUploadThrowsWhenFileMissing() async {
        tokenStore.save(BaiduPanCredentials(accessToken: "token"))
        let item = BackupItem(
            photoId: "missing",
            sha256: "hash-missing",
            filePath: "/tmp/does-not-exist-\(UUID().uuidString).heic",
            mimeType: "image/heic",
            byteSize: 0,
            updatedAt: 100
        )

        do {
            _ = try await provider.upload(item)
            XCTFail("Expected localFileNotFound")
        } catch let error as BaiduPanProviderError {
            XCTAssertEqual(error, .localFileNotFound(path: item.filePath))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testListReturnsLedgerItems() async throws {
        await ledger.record(
            BaiduPanRemoteFile(fsId: 1, remotePath: "/apps/babycamera/backups/a_hash-a.heic", sha256: "hash-a", byteSize: 10)
        )
        await ledger.record(
            BaiduPanRemoteFile(fsId: 2, remotePath: "/apps/babycamera/backups/b_hash-b.heic", sha256: "hash-b", byteSize: 20)
        )
        tokenStore.save(BaiduPanCredentials(accessToken: "token"))

        let page = try await provider.list(after: nil)
        XCTAssertEqual(page.items.map(\.sha256), ["hash-a", "hash-b"])
    }

    func testRevokeClearsTokenAndLedger() async throws {
        tokenStore.save(BaiduPanCredentials(accessToken: "token"))
        await ledger.record(
            BaiduPanRemoteFile(fsId: 1, remotePath: "/apps/babycamera/backups/a.heic", sha256: "hash-a", byteSize: 10)
        )

        try await provider.revoke()

        XCTAssertNil(tokenStore.load())
        let page = try await provider.list(after: nil)
        XCTAssertTrue(page.items.isEmpty)
    }

    func testRemotePathBuilderUsesMimeExtension() {
        XCTAssertEqual(
            BaiduPanProvider.remotePath(
                directory: "/apps/babycamera/backups",
                photoId: "p1",
                sha256: "abc",
                mimeType: "image/jpeg"
            ),
            "/apps/babycamera/backups/p1_abc.jpg"
        )
    }

    func testIntegrationWithBackupOrchestrator() async throws {
        let fileURL = try makeTemporaryFile(named: "photo.heic", contents: Data([0x0A, 0x0B]))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        tokenStore.save(BaiduPanCredentials(accessToken: "token"))

        let photoSource = MockBackupPhotoSource()
        photoSource.photos = [
            BackupPhotoCandidate(
                photoId: "p1",
                sha256: "hash-a",
                filePath: fileURL.path,
                byteSize: 2,
                updatedAt: 100
            ),
        ]

        let orchestrator = BackupOrchestrator(
            photoSource: photoSource,
            dedupStore: InMemoryBackupDedupStore(),
            deviceMonitor: MockBackupDeviceMonitor(snapshot: makeEligibleDevice())
        )

        let report = try await orchestrator.runBackup(
            trigger: .manual,
            providers: [provider],
            preferences: BackupAutoBackupPreferences()
        )

        XCTAssertEqual(report.totalUploadedCount, 1)
        XCTAssertEqual(openAPI.uploadedPaths.count, 1)
    }

    private func makeTemporaryFile(named name: String, contents: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BabyCameraBackupTests", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(UUID().uuidString)-\(name)")
        try contents.write(to: fileURL)
        return fileURL
    }
}

final class BaiduPanTokenStoreTests: XCTestCase {
    private let testService = "com.babycamera.tests.baidu-pan.\(UUID().uuidString)"

    override func tearDown() {
        KeychainBaiduPanTokenStore(service: testService).clear()
        super.tearDown()
    }

    func testInMemoryRoundTrip() {
        let store = InMemoryBaiduPanTokenStore()
        let credentials = BaiduPanCredentials(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 1_780_000_000),
            providerAccountId: "uid-1"
        )
        store.save(credentials)

        let loaded = store.load()
        XCTAssertEqual(loaded, credentials)
    }

    func testKeychainRoundTrip() {
        let store = KeychainBaiduPanTokenStore(service: testService)
        let credentials = BaiduPanCredentials(
            accessToken: "access-keychain",
            refreshToken: "refresh-keychain",
            expiresAt: Date(timeIntervalSince1970: 1_780_000_000),
            providerAccountId: "uid-keychain"
        )
        store.save(credentials)

        let reloaded = KeychainBaiduPanTokenStore(service: testService)
        XCTAssertEqual(reloaded.load(), credentials)
    }

    func testKeychainClear() {
        let store = KeychainBaiduPanTokenStore(service: testService)
        store.save(BaiduPanCredentials(accessToken: "x"))
        store.clear()
        XCTAssertNil(KeychainBaiduPanTokenStore(service: testService).load())
    }
}

final class BaiduPanChunkUploaderTests: XCTestCase {
    func testSplitAndUploadUsesPrecreateUploadCreate() async throws {
        let transport = RecordingBaiduPanTransport()
        transport.handlers = [
            .precreate(uploadId: "upload-1"),
            .uploadPart,
            .create(fsId: 99),
        ]

        let fileURL = try makeTemporaryFile(contents: Data(repeating: 0xAB, count: 3))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let uploader = BaiduPanChunkUploader(
            transport: transport,
            configuration: BaiduPanOpenAPIConfiguration(defaultChunkSize: 4)
        )

        let result = try await uploader.upload(
            accessToken: "token",
            localFileURL: fileURL,
            remotePath: "/apps/babycamera/backups/p1_hash.heic",
            resumeState: nil,
            chunkSize: 4,
            onProgress: nil
        )

        XCTAssertEqual(result.fsId, 99)
        XCTAssertEqual(transport.recordedPhases, [.precreate, .uploadPart, .create])
    }

    func testResumeSkipsCompletedParts() async throws {
        let transport = RecordingBaiduPanTransport()
        transport.handlers = [
            .uploadPart,
            .create(fsId: 100),
        ]

        let fileURL = try makeTemporaryFile(contents: Data(repeating: 0xCD, count: 8))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let uploader = BaiduPanChunkUploader(
            transport: transport,
            configuration: BaiduPanOpenAPIConfiguration(defaultChunkSize: 4)
        )

        let resume = BaiduPanMultipartState(
            uploadId: "upload-resume",
            remotePath: "/apps/babycamera/backups/p2_hash.heic",
            completedPartIndexes: [0]
        )

        let result = try await uploader.upload(
            accessToken: "token",
            localFileURL: fileURL,
            remotePath: resume.remotePath,
            resumeState: resume,
            chunkSize: 4,
            onProgress: nil
        )

        XCTAssertEqual(result.fsId, 100)
        XCTAssertEqual(transport.recordedPhases, [.uploadPart, .create])
    }

    private func makeTemporaryFile(contents: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BabyCameraBackupTests", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(UUID().uuidString).bin")
        try contents.write(to: fileURL)
        return fileURL
    }
}

private final class RecordingBaiduPanTransport: BaiduPanHTTPTransport, @unchecked Sendable {
    enum Phase: Equatable {
        case precreate
        case uploadPart
        case create
    }

    enum Handler {
        case precreate(uploadId: String)
        case uploadPart
        case create(fsId: Int64)
    }

    var handlers: [Handler] = []
    private(set) var recordedPhases: [Phase] = []
    private var handlerIndex = 0

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard handlerIndex < handlers.count else {
            throw BaiduPanProviderError.uploadFailed("unexpected request")
        }

        let handler = handlers[handlerIndex]
        handlerIndex += 1

        switch handler {
        case let .precreate(uploadId):
            recordedPhases.append(.precreate)
            let body = """
            {"errno":0,"uploadid":"\(uploadId)"}
            """
            return (Data(body.utf8), HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)

        case .uploadPart:
            recordedPhases.append(.uploadPart)
            return (Data(), HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)

        case let .create(fsId):
            recordedPhases.append(.create)
            let body = """
            {"errno":0,"fs_id":\(fsId)}
            """
            return (Data(body.utf8), HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }
    }
}
