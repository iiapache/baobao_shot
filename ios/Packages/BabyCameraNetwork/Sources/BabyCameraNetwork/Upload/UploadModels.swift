import Foundation

// MARK: - Purpose

public enum UploadPurpose: String, Encodable, Sendable {
    case aiInput = "ai-input"
    case postItem = "post-item"
}

// MARK: - Init

public struct UploadInitItemRequest: Encodable, Sendable {
    public let clientRef: String
    public let kind: String
    public let mime: String
    public let size: Int
    public let sha256: String?

    public init(
        clientRef: String,
        kind: String,
        mime: String,
        size: Int,
        sha256: String? = nil
    ) {
        self.clientRef = clientRef
        self.kind = kind
        self.mime = mime
        self.size = size
        self.sha256 = sha256
    }
}

public struct UploadInitRequest: Encodable, Sendable {
    public let purpose: UploadPurpose
    public let familyId: String?
    public let items: [UploadInitItemRequest]

    public init(purpose: UploadPurpose, familyId: String? = nil, items: [UploadInitItemRequest]) {
        self.purpose = purpose
        self.familyId = familyId
        self.items = items
    }
}

public struct STSCredentials: Decodable, Sendable, Equatable {
    public let accessKeyId: String
    public let accessKeySecret: String
    public let securityToken: String
    public let expiration: String

    public init(
        accessKeyId: String,
        accessKeySecret: String,
        securityToken: String,
        expiration: String
    ) {
        self.accessKeyId = accessKeyId
        self.accessKeySecret = accessKeySecret
        self.securityToken = securityToken
        self.expiration = expiration
    }
}

public struct UploadInitItemData: Decodable, Sendable, Equatable {
    public let clientRef: String
    public let objectKey: String
    public let uploadUrl: String
    public let method: String
    public let headers: [String: String]?
    public let expiresIn: Int

    public init(
        clientRef: String,
        objectKey: String,
        uploadUrl: String,
        method: String,
        headers: [String: String]?,
        expiresIn: Int
    ) {
        self.clientRef = clientRef
        self.objectKey = objectKey
        self.uploadUrl = uploadUrl
        self.method = method
        self.headers = headers
        self.expiresIn = expiresIn
    }
}

public struct UploadInitData: Decodable, Sendable, Equatable {
    public let uploadId: String
    public let sts: STSCredentials?
    public let items: [UploadInitItemData]

    public init(uploadId: String, sts: STSCredentials?, items: [UploadInitItemData]) {
        self.uploadId = uploadId
        self.sts = sts
        self.items = items
    }
}

// MARK: - Complete

public struct UploadCompleteRequest: Encodable, Sendable {
    public let uploadId: String

    public init(uploadId: String) {
        self.uploadId = uploadId
    }
}

public struct UploadCompleteItemData: Decodable, Sendable, Equatable {
    public let clientRef: String
    public let objectKey: String
    public let sha256: String?
    public let size: Int?
    public let mime: String?

    public init(
        clientRef: String,
        objectKey: String,
        sha256: String? = nil,
        size: Int? = nil,
        mime: String? = nil
    ) {
        self.clientRef = clientRef
        self.objectKey = objectKey
        self.sha256 = sha256
        self.size = size
        self.mime = mime
    }
}

public struct UploadCompleteData: Decodable, Sendable, Equatable {
    public let uploadId: String
    public let status: String
    public let items: [UploadCompleteItemData]

    public init(uploadId: String, status: String, items: [UploadCompleteItemData]) {
        self.uploadId = uploadId
        self.status = status
        self.items = items
    }
}

// MARK: - Client payload

public struct UploadPayloadItem: Sendable {
    public let clientRef: String
    public let kind: String
    public let mime: String
    public let data: Data
    public let sha256: String?

    public init(
        clientRef: String,
        kind: String,
        mime: String,
        data: Data,
        sha256: String? = nil
    ) {
        self.clientRef = clientRef
        self.kind = kind
        self.mime = mime
        self.data = data
        self.sha256 = sha256
    }
}

public struct UploadProgress: Sendable, Equatable {
    public let bytesUploaded: Int64
    public let totalBytes: Int64
    public let fractionCompleted: Double

    public init(bytesUploaded: Int64, totalBytes: Int64) {
        self.bytesUploaded = bytesUploaded
        self.totalBytes = totalBytes
        self.fractionCompleted = totalBytes > 0 ? Double(bytesUploaded) / Double(totalBytes) : 0
    }
}

public struct UploadResult: Sendable, Equatable {
    public let uploadId: String
    public let status: String
    public let items: [UploadCompleteItemData]

    public init(uploadId: String, status: String, items: [UploadCompleteItemData]) {
        self.uploadId = uploadId
        self.status = status
        self.items = items
    }
}

public struct UploadConfiguration: Sendable {
    /// 分片大小，默认 5 MB（OSS 最小分片 100 KB）
    public let chunkSize: Int
    /// 超过此大小走 OSS 分片上传
    public let multipartThreshold: Int
    /// 单分片 / 单次 PUT 最大重试次数
    public let maxRetries: Int
    /// 重试基础退避（秒），实际 delay = base * 2^(attempt-1)
    public let retryBaseDelay: TimeInterval

    public init(
        chunkSize: Int = 5 * 1024 * 1024,
        multipartThreshold: Int = 5 * 1024 * 1024,
        maxRetries: Int = 3,
        retryBaseDelay: TimeInterval = 0.5
    ) {
        self.chunkSize = chunkSize
        self.multipartThreshold = multipartThreshold
        self.maxRetries = maxRetries
        self.retryBaseDelay = retryBaseDelay
    }

    public static let `default` = UploadConfiguration()
}

public enum UploadError: Error, Sendable, Equatable {
    case missingItemData(clientRef: String)
    case missingSTSCredentials
    case invalidUploadURL(String)
    case ossUploadFailed(statusCode: Int)
    case multipartInitFailed
    case multipartCompleteFailed
    case exhaustedRetries(lastStatusCode: Int?)
    case itemCountMismatch
}
