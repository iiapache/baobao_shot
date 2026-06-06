import Foundation

// MARK: - Models

public struct AccountMeData: Decodable, Sendable, Equatable {
    public let userId: String
    public let nickname: String?
    public let avatarUrl: String?
    public let region: String
    public let consents: UserConsents?

    public init(
        userId: String,
        nickname: String?,
        avatarUrl: String?,
        region: String,
        consents: UserConsents?
    ) {
        self.userId = userId
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.region = region
        self.consents = consents
    }
}

public struct AccountDeletionData: Decodable, Sendable, Equatable {
    public let requestedAt: String
    public let scheduledAt: String
    public let revokeBefore: String

    public init(requestedAt: String, scheduledAt: String, revokeBefore: String) {
        self.requestedAt = requestedAt
        self.scheduledAt = scheduledAt
        self.revokeBefore = revokeBefore
    }
}

// MARK: - Endpoints

enum AccountEndpoint: Endpoint {
    case me
    case logout
    case deleteAccount

    var path: String {
        switch self {
        case .me:
            return "/v1/account/me"
        case .logout:
            return "/v1/account/logout"
        case .deleteAccount:
            return "/v1/account"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .me:
            return .get
        case .logout:
            return .post
        case .deleteAccount:
            return .delete
        }
    }
}

// MARK: - AccountAPI

public struct AccountAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /v1/account/me
    public func getMe() async throws -> AccountMeData {
        try await client.request(AccountEndpoint.me)
    }

    /// POST /v1/account/logout
    public func logout() async throws {
        _ = try await client.request(AccountEndpoint.logout, responseType: EmptyData.self)
    }

    /// DELETE /v1/account
    public func deleteAccount() async throws -> AccountDeletionData {
        try await client.request(AccountEndpoint.deleteAccount)
    }
}
