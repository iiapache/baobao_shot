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

public struct UpdateAccountMeRequest: Encodable, Sendable {
    public let nickname: String?

    public init(nickname: String?) {
        self.nickname = nickname
    }
}

public struct ChildDataConsentRequest: Encodable, Sendable {
    public let version: String
    public let accepted: Bool

    public init(version: String, accepted: Bool) {
        self.version = version
        self.accepted = accepted
    }
}

public struct ChildDataConsentData: Decodable, Sendable, Equatable {
    public let version: String
    public let agreedAt: String

    public init(version: String, agreedAt: String) {
        self.version = version
        self.agreedAt = agreedAt
    }
}

public struct ChildDataConsentStatusData: Decodable, Sendable, Equatable {
    public let currentVersion: String
    public let agreedVersion: String?
    public let agreed: Bool
    public let agreedAt: String?
    public let requiresConsent: Bool

    public init(
        currentVersion: String,
        agreedVersion: String?,
        agreed: Bool,
        agreedAt: String?,
        requiresConsent: Bool
    ) {
        self.currentVersion = currentVersion
        self.agreedVersion = agreedVersion
        self.agreed = agreed
        self.agreedAt = agreedAt
        self.requiresConsent = requiresConsent
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
    case updateMe(UpdateAccountMeRequest)
    case getChildDataConsent
    case submitChildDataConsent(ChildDataConsentRequest)
    case logout
    case deleteAccount

    var path: String {
        switch self {
        case .me, .updateMe:
            return "/v1/account/me"
        case .getChildDataConsent, .submitChildDataConsent:
            return "/v1/account/consents/child-data"
        case .logout:
            return "/v1/account/logout"
        case .deleteAccount:
            return "/v1/account"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .me, .getChildDataConsent:
            return .get
        case .updateMe:
            return .patch
        case .submitChildDataConsent:
            return .post
        case .logout:
            return .post
        case .deleteAccount:
            return .delete
        }
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case .me, .getChildDataConsent, .logout, .deleteAccount:
            return nil
        case let .updateMe(body):
            return try encoder.encode(body)
        case let .submitChildDataConsent(body):
            return try encoder.encode(body)
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

    /// PATCH /v1/account/me
    public func updateMe(nickname: String?) async throws -> AccountMeData {
        let request = UpdateAccountMeRequest(nickname: nickname)
        return try await client.request(AccountEndpoint.updateMe(request))
    }

    /// GET /v1/account/consents/child-data
    public func getChildDataConsentStatus() async throws -> ChildDataConsentStatusData {
        try await client.request(AccountEndpoint.getChildDataConsent)
    }

    /// POST /v1/account/consents/child-data
    public func submitChildDataConsent(version: String, accepted: Bool) async throws -> ChildDataConsentData {
        let request = ChildDataConsentRequest(version: version, accepted: accepted)
        return try await client.request(AccountEndpoint.submitChildDataConsent(request))
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
