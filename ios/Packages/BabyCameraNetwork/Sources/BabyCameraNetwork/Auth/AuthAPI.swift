import Foundation

// MARK: - Models

public struct AppleLoginRequest: Encodable, Sendable {
    public let identityToken: String
    public let authorizationCode: String
    public let nickname: String?
    public let region: String

    public init(
        identityToken: String,
        authorizationCode: String,
        nickname: String? = nil,
        region: String
    ) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.nickname = nickname
        self.region = region
    }
}

public struct PhoneCodeRequest: Encodable, Sendable {
    public let phone: String

    public init(phone: String) {
        self.phone = phone
    }
}

public struct PhoneLoginRequest: Encodable, Sendable {
    public let phone: String
    public let code: String
    public let region: String

    public init(phone: String, code: String, region: String) {
        self.phone = phone
        self.code = code
        self.region = region
    }
}

public struct RefreshTokenRequest: Encodable, Sendable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public struct UserProfile: Decodable, Sendable, Equatable {
    public let nickname: String?
    public let avatarUrl: String?
    public let region: String
    public let consents: UserConsents?

    public init(nickname: String?, avatarUrl: String?, region: String, consents: UserConsents?) {
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.region = region
        self.consents = consents
    }
}

public struct UserConsents: Decodable, Sendable, Equatable {
    public let childData: Bool?

    public init(childData: Bool?) {
        self.childData = childData
    }
}

public struct AuthLoginData: Decodable, Sendable, Equatable {
    public let userId: String
    public let isNewUser: Bool
    public let accessToken: String
    public let accessTokenExpiresIn: TimeInterval
    public let refreshToken: String
    public let refreshTokenExpiresIn: TimeInterval
    public let profile: UserProfile?

    public init(
        userId: String,
        isNewUser: Bool,
        accessToken: String,
        accessTokenExpiresIn: TimeInterval,
        refreshToken: String,
        refreshTokenExpiresIn: TimeInterval,
        profile: UserProfile?
    ) {
        self.userId = userId
        self.isNewUser = isNewUser
        self.accessToken = accessToken
        self.accessTokenExpiresIn = accessTokenExpiresIn
        self.refreshToken = refreshToken
        self.refreshTokenExpiresIn = refreshTokenExpiresIn
        self.profile = profile
    }
}

public struct RefreshTokenData: Decodable, Sendable, Equatable {
    public let accessToken: String
    public let accessTokenExpiresIn: TimeInterval
    public let refreshToken: String
    public let refreshTokenExpiresIn: TimeInterval

    public init(
        accessToken: String,
        accessTokenExpiresIn: TimeInterval,
        refreshToken: String,
        refreshTokenExpiresIn: TimeInterval
    ) {
        self.accessToken = accessToken
        self.accessTokenExpiresIn = accessTokenExpiresIn
        self.refreshToken = refreshToken
        self.refreshTokenExpiresIn = refreshTokenExpiresIn
    }
}

// MARK: - Endpoints

enum AuthEndpoint: Endpoint {
    case appleLogin(AppleLoginRequest)
    case phoneCode(PhoneCodeRequest)
    case phoneLogin(PhoneLoginRequest)
    case refresh(RefreshTokenRequest)

    var path: String {
        switch self {
        case .appleLogin:
            return "/v1/auth/apple"
        case .phoneCode:
            return "/v1/auth/phone/code"
        case .phoneLogin:
            return "/v1/auth/phone/login"
        case .refresh:
            return "/v1/auth/refresh"
        }
    }

    var method: HTTPMethod { .post }

    var authRequirement: AuthRequirement { .none }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .appleLogin(request):
            return try encoder.encode(request)
        case let .phoneCode(request):
            return try encoder.encode(request)
        case let .phoneLogin(request):
            return try encoder.encode(request)
        case let .refresh(request):
            return try encoder.encode(request)
        }
    }
}

// MARK: - AuthAPI

public struct AuthAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /v1/auth/apple
    public func appleLogin(
        identityToken: String,
        authorizationCode: String,
        nickname: String? = nil,
        region: AppRegion
    ) async throws -> AuthLoginData {
        let request = AppleLoginRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            nickname: nickname,
            region: region.rawValue
        )
        return try await client.request(AuthEndpoint.appleLogin(request))
    }

    /// POST /v1/auth/phone/code
    public func sendPhoneCode(phone: String) async throws {
        let request = PhoneCodeRequest(phone: phone)
        _ = try await client.request(
            AuthEndpoint.phoneCode(request),
            responseType: EmptyData.self
        )
    }

    /// POST /v1/auth/phone/login
    public func phoneLogin(phone: String, code: String, region: AppRegion) async throws -> AuthLoginData {
        let request = PhoneLoginRequest(phone: phone, code: code, region: region.rawValue)
        return try await client.request(AuthEndpoint.phoneLogin(request))
    }

    /// POST /v1/auth/refresh
    public func refresh(refreshToken: String) async throws -> RefreshTokenData {
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        return try await client.request(AuthEndpoint.refresh(request))
    }
}

public func makeAuthenticatedClient(
    region: AppRegion = .cn,
    tokenStore: TokenStore = KeychainTokenStore(),
    regionConfig: RegionConfig? = nil,
    loggingInterceptor: LoggingInterceptor? = nil,
    session: URLSession? = nil
) -> APIClient {
    let config = regionConfig ?? RegionConfig(region: region, appVersion: "1.0.0", deviceId: "test-device")
    var client: APIClient!
    let refreshHandler: TokenRefreshHandler = {
        guard let refreshToken = tokenStore.refreshToken() else {
            throw APIError(
                code: .authRefreshInvalid,
                message: "missing refresh token",
                httpStatusCode: 401
            )
        }
        let data = try await AuthAPI(client: client).refresh(refreshToken: refreshToken)
        return TokenPair(
            accessToken: data.accessToken,
            refreshToken: data.refreshToken,
            accessTokenExpiresIn: data.accessTokenExpiresIn,
            refreshTokenExpiresIn: data.refreshTokenExpiresIn
        )
    }
    let configuration = APIClientConfiguration.standard(
        region: region,
        tokenStore: tokenStore,
        regionConfig: config,
        loggingInterceptor: loggingInterceptor,
        refreshHandler: refreshHandler
    )
    client = APIClient(configuration: configuration, session: session)
    return client
}

/// 未注入 Token 的匿名客户端（登录 / 发码等）
public func makeAnonymousClient(
    region: AppRegion = .cn,
    regionConfig: RegionConfig? = nil,
    loggingInterceptor: LoggingInterceptor? = nil,
    session: URLSession? = nil
) -> APIClient {
    let tokenStore = InMemoryTokenStore()
    let config = regionConfig ?? RegionConfig(region: region, appVersion: "1.0.0", deviceId: "test-device")
    let configuration = APIClientConfiguration.standard(
        region: region,
        tokenStore: tokenStore,
        regionConfig: config,
        loggingInterceptor: loggingInterceptor,
        refreshHandler: nil
    )
    return APIClient(configuration: configuration, session: session)
}
