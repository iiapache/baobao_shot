import BabyCameraNetwork
import Foundation

public enum AuthServiceError: Error, Equatable, Sendable {
    case notAuthenticated
    case sessionRestoreFailed
}

public struct AuthServiceConfiguration: Sendable {
    public let region: AppRegion
    public let regionConfig: RegionConfig
    public let tokenStore: TokenStore
    public let session: URLSession

    public init(
        region: AppRegion = .cn,
        regionConfig: RegionConfig? = nil,
        tokenStore: TokenStore = KeychainTokenStore(),
        session: URLSession = .shared
    ) {
        self.region = region
        self.regionConfig = regionConfig ?? RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: AuthServiceConfiguration.resolveDeviceId()
        )
        self.tokenStore = tokenStore
        self.session = session
    }

    private static func resolveDeviceId() -> String {
        let key = "com.babycamera.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

public final class AuthService: @unchecked Sendable {
    public let tokenStore: TokenStore
    public let region: AppRegion

    private let regionConfig: RegionConfig
    private let session: URLSession
    private let clientFactory: @Sendable (TokenStore) -> APIClient

    public init(
        configuration: AuthServiceConfiguration = AuthServiceConfiguration(),
        clientFactory: (@Sendable (TokenStore) -> APIClient)? = nil
    ) {
        let region = configuration.region
        let regionConfig = configuration.regionConfig
        let session = configuration.session

        self.region = region
        self.regionConfig = regionConfig
        self.tokenStore = configuration.tokenStore
        self.session = session
        self.clientFactory = clientFactory ?? { tokenStore in
            makeAuthenticatedClient(
                region: region,
                tokenStore: tokenStore,
                regionConfig: regionConfig,
                session: session
            )
        }
    }

    public var isAuthenticated: Bool {
        tokenStore.refreshToken() != nil
    }

    private func authenticatedClient() -> APIClient {
        clientFactory(tokenStore)
    }

    private func anonymousClient() -> APIClient {
        makeAnonymousClient(
            region: region,
            regionConfig: regionConfig,
            session: session
        )
    }

    public func restoreSession() async throws -> AuthSession {
        guard tokenStore.refreshToken() != nil else {
            throw AuthServiceError.notAuthenticated
        }

        let client = authenticatedClient()
        let me = try await AccountAPI(client: client).getMe()
        return AuthSession(me: me)
    }

    public func loginWithApple(_ credential: AppleSignInCredential) async throws -> AuthSession {
        let client = anonymousClient()
        let login = try await AuthAPI(client: client).appleLogin(
            identityToken: credential.identityToken,
            authorizationCode: credential.authorizationCode,
            nickname: credential.nickname,
            region: region
        )
        persistTokens(from: login)
        return AuthSession(loginData: login)
    }

    public func sendPhoneVerificationCode(phone: String) async throws {
        let client = anonymousClient()
        try await AuthAPI(client: client).sendPhoneCode(phone: phone)
    }

    public func loginWithPhone(phone: String, code: String) async throws -> AuthSession {
        let client = anonymousClient()
        let login = try await AuthAPI(client: client).phoneLogin(
            phone: phone,
            code: code,
            region: region
        )
        persistTokens(from: login)
        return AuthSession(loginData: login)
    }

    public func logout() async throws {
        if tokenStore.accessToken() != nil {
            let client = authenticatedClient()
            try await AccountAPI(client: client).logout()
        }
        tokenStore.clear()
    }

    public func deleteAccount() async throws -> AccountDeletionResult {
        let client = authenticatedClient()
        let data = try await AccountAPI(client: client).deleteAccount()
        tokenStore.clear()
        return AccountDeletionResult(data: data)
    }

    private func persistTokens(from login: AuthLoginData) {
        tokenStore.save(
            TokenPair(
                accessToken: login.accessToken,
                refreshToken: login.refreshToken,
                accessTokenExpiresIn: login.accessTokenExpiresIn,
                refreshTokenExpiresIn: login.refreshTokenExpiresIn
            )
        )
    }
}
