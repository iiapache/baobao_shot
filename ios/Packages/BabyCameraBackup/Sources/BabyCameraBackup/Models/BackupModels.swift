import Foundation

public struct BackupQuota: Sendable, Equatable {
    public let usedBytes: Int64
    public let totalBytes: Int64?

    public init(usedBytes: Int64, totalBytes: Int64? = nil) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }
}

public struct BackupItem: Sendable, Equatable {
    public let photoId: String
    public let sha256: String
    public let filePath: String
    public let mimeType: String
    public let byteSize: Int64
    public let updatedAt: Int64

    public init(
        photoId: String,
        sha256: String,
        filePath: String,
        mimeType: String,
        byteSize: Int64,
        updatedAt: Int64
    ) {
        self.photoId = photoId
        self.sha256 = sha256
        self.filePath = filePath
        self.mimeType = mimeType
        self.byteSize = byteSize
        self.updatedAt = updatedAt
    }
}

public struct BackupReceipt: Sendable, Equatable {
    public let remoteId: String
    public let sha256: String
    public let uploadedAt: Int64

    public init(remoteId: String, sha256: String, uploadedAt: Int64) {
        self.remoteId = remoteId
        self.sha256 = sha256
        self.uploadedAt = uploadedAt
    }
}

public struct BackupRemoteItem: Sendable, Equatable {
    public let remoteId: String
    public let sha256: String

    public init(remoteId: String, sha256: String) {
        self.remoteId = remoteId
        self.sha256 = sha256
    }
}

public struct BackupPage: Sendable, Equatable {
    public let items: [BackupRemoteItem]
    public let nextCursor: String?

    public init(items: [BackupRemoteItem], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct BackupPhotoCandidate: Sendable, Equatable {
    public let photoId: String
    public let sha256: String
    public let filePath: String
    public let mimeType: String
    public let byteSize: Int64
    public let updatedAt: Int64

    public init(
        photoId: String,
        sha256: String,
        filePath: String,
        mimeType: String = "image/heic",
        byteSize: Int64 = 0,
        updatedAt: Int64
    ) {
        self.photoId = photoId
        self.sha256 = sha256
        self.filePath = filePath
        self.mimeType = mimeType
        self.byteSize = byteSize
        self.updatedAt = updatedAt
    }

    public func asBackupItem() -> BackupItem {
        BackupItem(
            photoId: photoId,
            sha256: sha256,
            filePath: filePath,
            mimeType: mimeType,
            byteSize: byteSize,
            updatedAt: updatedAt
        )
    }
}
