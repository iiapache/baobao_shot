import Foundation

/// Debug / UI 测试用 CloudKit 内存实现；不访问真实 iCloud。
public final class StubCloudKitPrivateDatabase: CloudKitPrivateDatabaseProviding, @unchecked Sendable {
    public var accountStatusResult: CloudKitAccountStatus = .available
    public var accountStatusError: Error?
    public private(set) var accountStatusCallCount = 0
    public private(set) var savedRecords: [CloudKitBackupRecordInput] = []
    public var storedRecords: [CloudKitBackupRecordSummary] = []
    public private(set) var deleteAllCallCount = 0

    public init(accountStatusResult: CloudKitAccountStatus = .available) {
        self.accountStatusResult = accountStatusResult
    }

    public func accountStatus() async throws -> CloudKitAccountStatus {
        accountStatusCallCount += 1
        if let accountStatusError { throw accountStatusError }
        return accountStatusResult
    }

    public func saveRecord(_ input: CloudKitBackupRecordInput) async throws -> CloudKitBackupRecordOutput {
        savedRecords.append(input)
        let summary = CloudKitBackupRecordSummary(
            recordID: ICloudBackupRecordSchema.recordName(for: input.photoId),
            photoId: input.photoId,
            sha256: input.sha256,
            byteSize: input.byteSize
        )
        storedRecords.removeAll { $0.photoId == input.photoId }
        storedRecords.append(summary)

        return CloudKitBackupRecordOutput(
            recordID: summary.recordID,
            photoId: input.photoId,
            sha256: input.sha256,
            byteSize: input.byteSize,
            uploadedAt: input.updatedAt
        )
    }

    public func fetchRecords(after cursor: String?, limit: Int) async throws -> CloudKitBackupRecordPage {
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

    public func deleteAllBackupRecords() async throws {
        deleteAllCallCount += 1
        storedRecords.removeAll()
        savedRecords.removeAll()
    }
}
