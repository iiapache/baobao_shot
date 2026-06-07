import Foundation

// MARK: - Models

public struct BackupProviderData: Decodable, Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: String
    public let status: String
    public let providerAccountId: String?
    public let expiresAt: String?
    public let metadata: [String: String]
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: String,
        kind: String,
        status: String,
        providerAccountId: String? = nil,
        expiresAt: String? = nil,
        metadata: [String: String] = [:],
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.providerAccountId = providerAccountId
        self.expiresAt = expiresAt
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct BackupProviderListData: Decodable, Sendable, Equatable {
    public let items: [BackupProviderData]

    public init(items: [BackupProviderData]) {
        self.items = items
    }
}

public struct BackupStatusData: Decodable, Sendable, Equatable {
    public let lastSuccessAt: String?
    public let lastAttemptAt: String?
    public let failureCount: Int
    public let lastErrorCode: String?

    public init(
        lastSuccessAt: String? = nil,
        lastAttemptAt: String? = nil,
        failureCount: Int = 0,
        lastErrorCode: String? = nil
    ) {
        self.lastSuccessAt = lastSuccessAt
        self.lastAttemptAt = lastAttemptAt
        self.failureCount = failureCount
        self.lastErrorCode = lastErrorCode
    }
}

public struct UnbindBackupProviderData: Decodable, Sendable, Equatable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public struct BindBackupProviderRequest: Encodable, Sendable, Equatable {
    public let kind: String
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: String?
    public let providerAccountId: String?
    public let metadata: [String: String]?

    public init(
        kind: String,
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: String? = nil,
        providerAccountId: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.kind = kind
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.providerAccountId = providerAccountId
        self.metadata = metadata
    }
}

public struct ReportBackupStatusRequest: Encodable, Sendable, Equatable {
    public let success: Bool
    public let attemptedAt: String
    public let errorCode: String?

    public init(success: Bool, attemptedAt: String, errorCode: String? = nil) {
        self.success = success
        self.attemptedAt = attemptedAt
        self.errorCode = errorCode
    }
}

// MARK: - Endpoints

enum BackupEndpoint: Endpoint {
    case bindProvider(BindBackupProviderRequest)
    case listProviders
    case unbindProvider(String)
    case getStatus
    case reportStatus(ReportBackupStatusRequest)

    var path: String {
        switch self {
        case .bindProvider, .listProviders:
            return "/v1/backup/providers"
        case let .unbindProvider(id):
            return "/v1/backup/providers/\(id)"
        case .getStatus, .reportStatus:
            return "/v1/backup/status"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .bindProvider, .reportStatus:
            return .post
        case .listProviders, .getStatus:
            return .get
        case .unbindProvider:
            return .delete
        }
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .bindProvider(body):
            return try encoder.encode(body)
        case let .reportStatus(body):
            return try encoder.encode(body)
        default:
            return nil
        }
    }
}

// MARK: - BackupAPI

/// auth-family-svc 备份凭据 API 客户端（T6.6）。
public struct BackupAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /v1/backup/providers
    public func bindProvider(_ request: BindBackupProviderRequest) async throws -> BackupProviderData {
        try await client.request(BackupEndpoint.bindProvider(request))
    }

    /// GET /v1/backup/providers
    public func listProviders() async throws -> BackupProviderListData {
        try await client.request(BackupEndpoint.listProviders)
    }

    /// DELETE /v1/backup/providers/{id}
    public func unbindProvider(id: String) async throws -> UnbindBackupProviderData {
        try await client.request(BackupEndpoint.unbindProvider(id))
    }

    /// GET /v1/backup/status
    public func getStatus() async throws -> BackupStatusData {
        try await client.request(BackupEndpoint.getStatus)
    }

    /// POST /v1/backup/status
    public func reportStatus(_ request: ReportBackupStatusRequest) async throws -> BackupStatusData {
        try await client.request(BackupEndpoint.reportStatus(request))
    }
}
