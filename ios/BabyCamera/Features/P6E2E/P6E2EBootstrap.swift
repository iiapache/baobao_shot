import BabyCameraAccount
import BabyCameraNetwork
import Foundation

enum P6E2EBootstrap {
    static func configureIfNeeded() {
        guard UITestLaunchConfiguration.isP6E2EMode else { return }
        MockURLProtocol.register(handler: MockServer.p6E2EHandler())
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("com.babycamera.") {
            defaults.removeObject(forKey: key)
        }
    }

    static func makeCoordinator() -> AccountCoordinator {
        configureIfNeeded()
        let tokenStore = InMemoryTokenStore()
        let mockSession = MockURLProtocol.makeSession()
        let regionConfig = RegionConfig(
            region: .cn,
            appVersion: "1.0.0-staging",
            deviceId: "qa-device-p6-uitest-001"
        )
        let authService = AuthService(
            configuration: AuthServiceConfiguration(
                region: .cn,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: mockSession
            )
        )
        tokenStore.save(TokenPair(accessToken: "mock_access_token_admin", refreshToken: "mock_refresh"))
        let coordinator = AccountCoordinator(authService: authService)
        coordinator.handleAuthenticated(
            AuthSession(
                userId: "usr_e2e_uitest",
                isNewUser: false,
                profile: UserProfile(
                    nickname: "P6 E2E",
                    avatarUrl: nil,
                    region: "cn",
                    consents: ["childData": true]
                )
            )
        )
        return coordinator
    }
}
