import Foundation

public struct BaiduPanCredentials: Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    public let providerAccountId: String?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        providerAccountId: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.providerAccountId = providerAccountId
    }
}

public struct BaiduPanQuotaInfo: Sendable, Equatable {
    public let usedBytes: Int64
    public let totalBytes: Int64

    public init(usedBytes: Int64, totalBytes: Int64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }
}

/// 分片上传断点状态，用于失败后续传。
public struct BaiduPanMultipartState: Sendable, Equatable, Codable {
    public let uploadId: String
    public let remotePath: String
    public var completedPartIndexes: [Int]

    public init(uploadId: String, remotePath: String, completedPartIndexes: [Int] = []) {
        self.uploadId = uploadId
        self.remotePath = remotePath
        self.completedPartIndexes = completedPartIndexes
    }
}

public struct BaiduPanUploadResult: Sendable, Equatable {
    public let fsId: Int64
    public let remotePath: String
    public let resumeState: BaiduPanMultipartState?

    public init(fsId: Int64, remotePath: String, resumeState: BaiduPanMultipartState? = nil) {
        self.fsId = fsId
        self.remotePath = remotePath
        self.resumeState = resumeState
    }
}

public struct BaiduPanRemoteFile: Sendable, Equatable {
    public let fsId: Int64
    public let remotePath: String
    public let sha256: String
    public let byteSize: Int64

    public init(fsId: Int64, remotePath: String, sha256: String, byteSize: Int64) {
        self.fsId = fsId
        self.remotePath = remotePath
        self.sha256 = sha256
        self.byteSize = byteSize
    }
}

public struct BaiduPanFileListPage: Sendable, Equatable {
    public let files: [BaiduPanRemoteFile]
    public let nextStart: Int?

    public init(files: [BaiduPanRemoteFile], nextStart: Int? = nil) {
        self.files = files
        self.nextStart = nextStart
    }
}
