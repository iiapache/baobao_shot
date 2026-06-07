import XCTest
@testable import BabyCameraBackup

final class ICloudProviderTests: XCTestCase {
    private var database: MockCloudKitPrivateDatabase!
    private var clock: ControllableBackupClock!
    private var provider: ICloudProvider!

    override func setUp() {
        super.setUp()
        database = MockCloudKitPrivateDatabase()
        clock = ControllableBackupClock()
        provider = ICloudProvider(
            database: database,
            clock: clock,
            listPageSize: 2
        )
    }

    func testKindIsICloud() {
        XCTAssertEqual(provider.kind, .iCloud)
    }

    func testAuthorizeThrowsWhenNoAccount() async {
        database.accountStatusResult = .noAccount

        do {
            try await provider.authorize()
            XCTFail("Expected iCloudUnavailable")
        } catch let error as ICloudProviderError {
            XCTAssertEqual(error, .iCloudUnavailable(.noAccount))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAuthorizeSucceedsWhenAvailable() async throws {
        database.accountStatusResult = .available
        try await provider.authorize()
        XCTAssertEqual(database.accountStatusCallCount, 1)
    }

    func testUploadReadsFileAndSavesToCloudKit() async throws {
        let fileURL = try makeTemporaryFile(named: "photo.heic", contents: Data([0x01, 0x02, 0x03]))
        defer { try? FileManager.default.removeItem(at: fileURL) }

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

        XCTAssertEqual(database.savedRecords.count, 1)
        XCTAssertEqual(database.savedRecords[0].photoId, "p1")
        XCTAssertEqual(database.savedRecords[0].sha256, "hash-a")
        XCTAssertEqual(database.savedRecords[0].fileURL, fileURL)
        XCTAssertEqual(receipt.remoteId, ICloudBackupRecordSchema.recordName(for: "p1"))
        XCTAssertEqual(receipt.sha256, "hash-a")
        XCTAssertEqual(receipt.uploadedAt, clock.nowUnixMillis())
    }

    func testUploadThrowsWhenFileMissing() async {
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
        } catch let error as ICloudProviderError {
            XCTAssertEqual(error, .localFileNotFound(path: item.filePath))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testListReturnsStoredRecords() async throws {
        database.storedRecords = [
            CloudKitBackupRecordSummary(
                recordID: ICloudBackupRecordSchema.recordName(for: "p1"),
                photoId: "p1",
                sha256: "hash-a",
                byteSize: 100
            ),
            CloudKitBackupRecordSummary(
                recordID: ICloudBackupRecordSchema.recordName(for: "p2"),
                photoId: "p2",
                sha256: "hash-b",
                byteSize: 200
            ),
        ]

        let page = try await provider.list(after: nil)

        XCTAssertEqual(page.items.count, 2)
        XCTAssertEqual(page.items[0].remoteId, ICloudBackupRecordSchema.recordName(for: "p1"))
        XCTAssertEqual(page.items[0].sha256, "hash-a")
        XCTAssertNil(page.nextCursor)
    }

    func testListPaginationWithCursor() async throws {
        database.storedRecords = [
            CloudKitBackupRecordSummary(
                recordID: ICloudBackupRecordSchema.recordName(for: "p1"),
                photoId: "p1",
                sha256: "hash-a",
                byteSize: 100
            ),
            CloudKitBackupRecordSummary(
                recordID: ICloudBackupRecordSchema.recordName(for: "p2"),
                photoId: "p2",
                sha256: "hash-b",
                byteSize: 200
            ),
            CloudKitBackupRecordSummary(
                recordID: ICloudBackupRecordSchema.recordName(for: "p3"),
                photoId: "p3",
                sha256: "hash-c",
                byteSize: 300
            ),
        ]

        let firstPage = try await provider.list(after: nil)
        XCTAssertEqual(firstPage.items.map(\.sha256), ["hash-a", "hash-b"])
        XCTAssertEqual(firstPage.nextCursor, "p2")

        let secondPage = try await provider.list(after: firstPage.nextCursor)
        XCTAssertEqual(secondPage.items.map(\.sha256), ["hash-c"])
        XCTAssertNil(secondPage.nextCursor)
    }

    func testQuotaSumsStoredByteSizes() async throws {
        database.storedRecords = [
            CloudKitBackupRecordSummary(
                recordID: ICloudBackupRecordSchema.recordName(for: "p1"),
                photoId: "p1",
                sha256: "hash-a",
                byteSize: 100
            ),
            CloudKitBackupRecordSummary(
                recordID: ICloudBackupRecordSchema.recordName(for: "p2"),
                photoId: "p2",
                sha256: "hash-b",
                byteSize: 250
            ),
        ]

        let quota = try await provider.quota()

        XCTAssertEqual(quota.usedBytes, 350)
        XCTAssertNil(quota.totalBytes)
    }

    func testRevokeDeletesAllRecords() async throws {
        try await provider.revoke()
        XCTAssertEqual(database.deleteAllCallCount, 1)
    }

    func testIntegrationWithBackupOrchestrator() async throws {
        let fileURL = try makeTemporaryFile(named: "photo.heic", contents: Data([0x0A, 0x0B]))
        defer { try? FileManager.default.removeItem(at: fileURL) }

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
        XCTAssertEqual(database.savedRecords.map(\.sha256), ["hash-a"])
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

final class MockCloudKitPrivateDatabase: CloudKitPrivateDatabaseProviding, @unchecked Sendable {
    var accountStatusResult: CloudKitAccountStatus = .available
    var accountStatusError: Error?
    private(set) var accountStatusCallCount = 0
    private(set) var savedRecords: [CloudKitBackupRecordInput] = []
    var storedRecords: [CloudKitBackupRecordSummary] = []
    private(set) var deleteAllCallCount = 0

    func accountStatus() async throws -> CloudKitAccountStatus {
        accountStatusCallCount += 1
        if let accountStatusError { throw accountStatusError }
        return accountStatusResult
    }

    func saveRecord(_ input: CloudKitBackupRecordInput) async throws -> CloudKitBackupRecordOutput {
        savedRecords.append(input)
        return CloudKitBackupRecordOutput(
            recordID: ICloudBackupRecordSchema.recordName(for: input.photoId),
            photoId: input.photoId,
            sha256: input.sha256,
            byteSize: input.byteSize,
            uploadedAt: input.updatedAt
        )
    }

    func fetchRecords(after cursor: String?, limit: Int) async throws -> CloudKitBackupRecordPage {
        let sorted = storedRecords.sorted { $0.photoId < $1.photoId }
        let filtered: [CloudKitBackupRecordSummary]
        if let cursor {
            filtered = sorted.filter { $0.photoId > cursor }
        } else {
            filtered = sorted
        }

        let pageRecords: [CloudKitBackupRecordSummary]
        let nextCursor: String?
        if filtered.count > limit {
            pageRecords = Array(filtered.prefix(limit))
            nextCursor = pageRecords.last?.photoId
        } else {
            pageRecords = filtered
            nextCursor = nil
        }

        return CloudKitBackupRecordPage(records: pageRecords, nextCursor: nextCursor)
    }

    func deleteAllBackupRecords() async throws {
        deleteAllCallCount += 1
        storedRecords.removeAll()
        savedRecords.removeAll()
    }
}
