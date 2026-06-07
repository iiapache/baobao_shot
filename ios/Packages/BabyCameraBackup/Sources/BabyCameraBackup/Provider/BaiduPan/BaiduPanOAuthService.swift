import Foundation

public protocol BaiduPanOAuthProviding: Sendable {
    func authorize() async throws -> BaiduPanCredentials
}

/// OAuth 2.0 stub：模拟 ASWebAuthenticationSession 授权回调，不发起真实网络请求。
public struct StubBaiduPanOAuthService: BaiduPanOAuthProviding, Sendable {
    public let credentials: BaiduPanCredentials
    public var shouldFail: Bool

    public init(
        credentials: BaiduPanCredentials = BaiduPanCredentials(
            accessToken: "baidu-access-stub",
            refreshToken: "baidu-refresh-stub",
            expiresAt: Date(timeIntervalSince1970: 1_780_000_000),
            providerAccountId: "baidu-user-stub"
        ),
        shouldFail: Bool = false
    ) {
        self.credentials = credentials
        self.shouldFail = shouldFail
    }

    public func authorize() async throws -> BaiduPanCredentials {
        if shouldFail {
            throw BaiduPanProviderError.authorizationFailed("oauth cancelled")
        }
        return credentials
    }
}

/// 生产占位：后续接入 ASWebAuthenticationSession + 百度 OAuth 端点。
public struct LiveBaiduPanOAuthService: BaiduPanOAuthProviding, Sendable {
    private let clientId: String
    private let redirectURI: String

    public init(
        clientId: String = "babycamera-baidu-client-id",
        redirectURI: String = "babycamera://oauth/baidu"
    ) {
        self.clientId = clientId
        self.redirectURI = redirectURI
    }

    public func authorize() async throws -> BaiduPanCredentials {
        throw BaiduPanProviderError.authorizationFailed(
            "Live OAuth not configured; use StubBaiduPanOAuthService in development"
        )
    }
}
