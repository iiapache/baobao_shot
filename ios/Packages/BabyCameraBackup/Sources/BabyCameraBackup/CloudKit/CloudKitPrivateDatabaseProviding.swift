import Foundation

public enum CloudKitAccountStatus: Sendable, Equatable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
}

public struct CloudKitBackupRecordInput: Sendable, Equatable {
    public let photoId: String
    public let sha256: String
    public let mimeType: String
    public let byteSize: Int64
    public let updatedAt: Int64
    public let fileURL: URL

    public init(
        photoId: String,
        sha256: String,
        mimeType: String,
        byteSize: Int64,
        updatedAt: Int64,
        fileURL: URL
    ) {
        self.photoId = photoId
        self.sha256 = sha256
        self.mimeType = mimeType
        self.byteSize = byteSize
        self.updatedAt = updatedAt
        self.fileURL = fileURL
    }
}

public struct CloudKitBackupRecordOutput: Sendable, Equatable {
    public let recordID: String
    public let photoId: String
    public let sha256: String
    public let byteSize: Int64
    public let uploadedAt: Int64

    public init(
        recordID: String,
        photoId: String,
        sha256: String,
        byteSize: Int64,
        uploadedAt: Int64
    ) {
        self.recordID = recordID
        self.photoId = photoId
        self.sha256 = sha256
        self.byteSize = byteSize
        self.uploadedAt = uploadedAt
    }
}

public struct CloudKitBackupRecordSummary: Sendable, Equatable {
    public let recordID: String
    public let photoId: String
    public let sha256: String
    public let byteSize: Int64

    public init(recordID: String, photoId: String, sha256: String, byteSize: Int64) {
        self.recordID = recordID
        self.photoId = photoId
        self.sha256 = sha256
        self.byteSize = byteSize
    }
}

public struct CloudKitBackupRecordPage: Sendable, Equatable {
    public let records: [CloudKitBackupRecordSummary]
    public let nextCursor: String?

    public init(records: [CloudKitBackupRecordSummary], nextCursor: String? = nil) {
        self.records = records
        self.nextCursor = nextCursor
    }
}

public enum CloudKitPrivateDatabaseError: Error, Sendable, Equatable {
    case accountStatusUnavailable
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
}

/// CloudKit Private Database 抽象，便于单测注入 mock。
public protocol CloudKitPrivateDatabaseProviding: Sendable {
    func accountStatus() async throws -> CloudKitAccountStatus
    func saveRecord(_ input: CloudKitBackupRecordInput) async throws -> CloudKitBackupRecordOutput
    func fetchRecords(after cursor: String?, limit: Int) async throws -> CloudKitBackupRecordPage
    func deleteAllBackupRecords() async throws
}
