import XCTest
@testable import BabyCameraBackup

#if canImport(Photos)
import Photos
#endif

// MARK: - Mocks

final class MockPhotosAddOnlyPermissionService: PhotosAddOnlyPermissionChecking, @unchecked Sendable {
    var status: PhotosAddOnlyAuthorizationStatus = .notDetermined
    var requestResult: PhotosAddOnlyAuthorizationStatus = .authorized
    private(set) var requestCount = 0

    func authorizationStatus() -> PhotosAddOnlyAuthorizationStatus { status }

    func requestAuthorization() async -> PhotosAddOnlyAuthorizationStatus {
        requestCount += 1
        status = requestResult
        return requestResult
    }
}

final class MockPhotosLibraryWriter: PhotosLibraryWriting, @unchecked Sendable {
    struct WriteCall: Equatable {
        let path: String
        let albumTitle: String
    }

    private(set) var writeCalls: [WriteCall] = []
    var writeError: Error?
    var writeResult = PhotosWriteResult(assetLocalIdentifier: "mock-asset-1", byteSize: 1_024)

    func writeImage(from fileURL: URL, albumTitle: String) async throws -> PhotosWriteResult {
        writeCalls.append(WriteCall(path: fileURL.path, albumTitle: albumTitle))
        if let writeError { throw writeError }
        return writeResult
    }
}

final class PhotosProviderTests: XCTestCase {
    private var permission: MockPhotosAddOnlyPermissionService!
    private var writer: MockPhotosLibraryWriter!
    private var ledger: InMemoryPhotosWriteLedger!
    private var provider: PhotosProvider!
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        permission = MockPhotosAddOnlyPermissionService()
        writer = MockPhotosLibraryWriter()
        ledger = InMemoryPhotosWriteLedger()
        provider = PhotosProvider(
            permission: permission,
            writer: writer,
            ledger: ledger,
            clock: { 1_700_000_000_000 }
        )
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotosProviderTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    private func writeTempFile(named name: String, contents: String = "photo-bytes") -> URL {
        let url = tempDirectory.appendingPathComponent(name)
        try! contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeItem(
        photoId: String = "p1",
        sha256: String = "hash-a",
        filePath: String
    ) -> BackupItem {
        BackupItem(
            photoId: photoId,
            sha256: sha256,
            filePath: filePath,
            mimeType: "image/heic",
            byteSize: 12,
            updatedAt: 100
        )
    }

    func testKindIsPhotos() {
        XCTAssertEqual(provider.kind, .photos)
    }

    func testAuthorizeRequestsAddOnlyWhenNotDetermined() async throws {
        permission.status = .notDetermined
        permission.requestResult = .authorized

        try await provider.authorize()

        XCTAssertEqual(permission.requestCount, 1)
    }

    func testAuthorizeSkipsRequestWhenAlreadyAuthorized() async throws {
        permission.status = .authorized

        try await provider.authorize()

        XCTAssertEqual(permission.requestCount, 0)
    }

    func testAuthorizeThrowsWhenDenied() async {
        permission.status = .denied

        do {
            try await provider.authorize()
            XCTFail("Expected authorizationDenied")
        } catch let error as PhotosProviderError {
            XCTAssertEqual(error, .authorizationDenied)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAuthorizeThrowsWhenRestricted() async {
        permission.status = .restricted

        do {
            try await provider.authorize()
            XCTFail("Expected authorizationRestricted")
        } catch let error as PhotosProviderError {
            XCTAssertEqual(error, .authorizationRestricted)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUploadWritesToAlbumAndRecordsLedger() async throws {
        permission.status = .authorized
        let fileURL = writeTempFile(named: "photo.heic")
        writer.writeResult = PhotosWriteResult(assetLocalIdentifier: "asset-42", byteSize: 2_048)

        let receipt = try await provider.upload(
            makeItem(filePath: fileURL.path)
        )

        XCTAssertEqual(receipt.remoteId, "asset-42")
        XCTAssertEqual(receipt.sha256, "hash-a")
        XCTAssertEqual(receipt.uploadedAt, 1_700_000_000_000)
        XCTAssertEqual(writer.writeCalls.count, 1)
        XCTAssertEqual(writer.writeCalls[0].albumTitle, PhotosProvider.defaultAlbumTitle)

        let page = try await provider.list(after: nil)
        XCTAssertEqual(page.items, [BackupRemoteItem(remoteId: "asset-42", sha256: "hash-a")])
    }

    func testUploadThrowsWhenAuthorizationDenied() async {
        permission.status = .denied
        let fileURL = writeTempFile(named: "photo.heic")

        do {
            _ = try await provider.upload(makeItem(filePath: fileURL.path))
            XCTFail("Expected authorizationDenied")
        } catch let error as PhotosProviderError {
            XCTAssertEqual(error, .authorizationDenied)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUploadThrowsWhenFileMissing() async {
        permission.status = .authorized
        writer.writeError = PhotosProviderError.fileNotFound(path: "/missing.heic")

        do {
            _ = try await provider.upload(makeItem(filePath: "/missing.heic"))
            XCTFail("Expected fileNotFound")
        } catch let error as PhotosProviderError {
            XCTAssertEqual(error, .fileNotFound(path: "/missing.heic"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testListReturnsOnlyLedgerItemsWithoutReadingUserAlbum() async throws {
        permission.status = .authorized
        let fileURL = writeTempFile(named: "only-ours.heic")
        _ = try await provider.upload(makeItem(sha256: "ours", filePath: fileURL.path))

        let page = try await provider.list(after: nil)

        XCTAssertEqual(page.items.map(\.sha256), ["ours"])
        XCTAssertEqual(writer.writeCalls.count, 1)
    }

    func testListPaginatesWithCursor() async throws {
        permission.status = .authorized
        for index in 0..<3 {
            let fileURL = writeTempFile(named: "photo-\(index).heic")
            writer.writeResult = PhotosWriteResult(
                assetLocalIdentifier: "asset-\(index)",
                byteSize: Int64(index + 1)
            )
            _ = try await provider.upload(
                makeItem(photoId: "p\(index)", sha256: "hash-\(index)", filePath: fileURL.path)
            )
        }

        let firstPage = await ledger.page(after: nil, limit: 2)
        XCTAssertEqual(firstPage.items.map(\.remoteId), ["asset-0", "asset-1"])
        XCTAssertEqual(firstPage.nextCursor, "asset-1")

        let secondPage = try await provider.list(after: firstPage.nextCursor)
        XCTAssertEqual(secondPage.items.map(\.remoteId), ["asset-2"])
        XCTAssertNil(secondPage.nextCursor)
    }

    func testQuotaReflectsLedgerUsedBytes() async throws {
        permission.status = .authorized
        let fileURL = writeTempFile(named: "quota.heic")
        writer.writeResult = PhotosWriteResult(assetLocalIdentifier: "asset-q", byteSize: 9_999)

        _ = try await provider.upload(makeItem(filePath: fileURL.path))

        let quota = try await provider.quota()
        XCTAssertEqual(quota.usedBytes, 9_999)
        XCTAssertNil(quota.totalBytes)
    }

    func testRevokeClearsLedger() async throws {
        permission.status = .authorized
        let fileURL = writeTempFile(named: "revoke.heic")
        _ = try await provider.upload(makeItem(filePath: fileURL.path))

        try await provider.revoke()

        let page = try await provider.list(after: nil)
        XCTAssertTrue(page.items.isEmpty)
        let quota = try await provider.quota()
        XCTAssertEqual(quota.usedBytes, 0)
    }

    func testStubWriterGeneratesDeterministicAssetID() async throws {
        let stubWriter = StubPhotosLibraryWriter()
        let fileURL = writeTempFile(named: "stub.heic")

        let result = try await stubWriter.writeImage(
            from: fileURL,
            albumTitle: PhotosProvider.defaultAlbumTitle
        )

        XCTAssertEqual(result.assetLocalIdentifier, "stub-photos-stub.heic")
        XCTAssertGreaterThan(result.byteSize, 0)
    }

    func testIntegrationWithOrchestrator() async throws {
        permission.status = .authorized
        let fileURL = writeTempFile(named: "orch.heic")
        let photoSource = MockBackupPhotoSource()
        photoSource.photos = [
            BackupPhotoCandidate(
                photoId: "p1",
                sha256: "hash-orch",
                filePath: fileURL.path,
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
        XCTAssertEqual(report.providerResults[0].kind, .photos)
        XCTAssertEqual(writer.writeCalls.count, 1)
    }

    #if canImport(Photos)
    func testLivePermissionServiceUsesAddOnlyAccessLevel() {
        XCTAssertEqual(LivePhotosAddOnlyPermissionService.accessLevel, .addOnly)
    }
    #endif
}
