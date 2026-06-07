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

/// 真机 OAuth：ASWebAuthenticationSession 授权 + 百度 token 端点换票。
public struct LiveBaiduPanOAuthService: BaiduPanOAuthProviding, Sendable {
    private let clientID: String
    private let redirectURI: String
    private let clientSecret: String?
    private let tokenClient: any BaiduPanOAuthTokenExchanging

    public init(
        clientID: String = BaiduPanOAuthConfiguration.defaultClientID,
        redirectURI: String = BaiduPanOAuthConfiguration.defaultRedirectURI,
        clientSecret: String? = nil,
        tokenClient: any BaiduPanOAuthTokenExchanging = URLSessionBaiduPanOAuthTokenClient()
    ) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.clientSecret = clientSecret
        self.tokenClient = tokenClient
    }

    public init(
        configurationBundle: Bundle = .main,
        tokenClient: any BaiduPanOAuthTokenExchanging = URLSessionBaiduPanOAuthTokenClient()
    ) {
        self.init(
            clientID: BaiduPanOAuthConfiguration.clientIDFromInfoPlist(bundle: configurationBundle),
            redirectURI: BaiduPanOAuthConfiguration.redirectURIFromInfoPlist(bundle: configurationBundle),
            clientSecret: BaiduPanOAuthConfiguration.clientSecretFromInfoPlist(bundle: configurationBundle),
            tokenClient: tokenClient
        )
    }

    public func authorize() async throws -> BaiduPanCredentials {
        guard let clientSecret, !clientSecret.isEmpty else {
            throw BaiduPanProviderError.authorizationFailed(
                "BaiduPanClientSecret missing; copy BaiduPan.Secrets.xcconfig.example"
            )
        }
        guard let callbackScheme = BaiduPanOAuthConfiguration.callbackURLScheme(for: redirectURI) else {
            throw BaiduPanProviderError.authorizationFailed("invalid redirect uri")
        }

        let state = UUID().uuidString
        guard let authorizeURL = BaiduPanOAuthConfiguration.makeAuthorizeURL(
            clientID: clientID,
            redirectURI: redirectURI,
            state: state
        ) else {
            throw BaiduPanProviderError.authorizationFailed("failed to build authorize url")
        }

        let callbackURL = try await startWebAuth(url: authorizeURL, callbackURLScheme: callbackScheme)
        let code = try Self.parseAuthorizationCode(from: callbackURL, expectedState: state)
        let token = try await tokenClient.exchangeAuthorizationCode(
            code: code,
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: redirectURI
        )
        let providerAccountId = try? await tokenClient.fetchLoggedInUserID(accessToken: token.accessToken)
        let expiresAt = token.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }

        return BaiduPanCredentials(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: expiresAt,
            providerAccountId: providerAccountId
        )
    }

    private func startWebAuth(url: URL, callbackURLScheme: String) async throws -> URL {
        #if canImport(AuthenticationServices) && canImport(UIKit)
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let starter = BaiduPanWebAuthSessionStarter()
                starter.start(url: url, callbackURLScheme: callbackURLScheme) { result in
                    continuation.resume(with: result)
                }
            }
        }
        #else
        throw BaiduPanProviderError.authorizationFailed("ASWebAuthenticationSession unavailable")
        #endif
    }

    static func parseAuthorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw BaiduPanProviderError.authorizationFailed("invalid callback url")
        }
        let queryItems = components.queryItems ?? []
        let values = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        if let error = values["error"], !error.isEmpty {
            let description = values["error_description"] ?? error
            throw BaiduPanProviderError.authorizationFailed(description)
        }

        guard let state = values["state"], state == expectedState else {
            throw BaiduPanProviderError.authorizationFailed("oauth state mismatch")
        }
        guard let code = values["code"], !code.isEmpty else {
            throw BaiduPanProviderError.authorizationFailed("missing authorization code")
        }
        return code
    }
}
