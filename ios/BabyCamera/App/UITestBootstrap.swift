import BabyCameraAccount
import BabyCameraNetwork
import BabyCameraOnboarding
import Foundation

enum UITestBootstrap {
    static let launchArgument = "-UITesting"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
            && !ProcessInfo.processInfo.arguments.contains("-P2E2E")
            && !ProcessInfo.processInfo.arguments.contains("-P6E2E")
    }

    static func configureIfNeeded() {
        guard isEnabled else { return }
        MockURLProtocol.register(handler: MockServer.uitestMainAppHandler())
        resetPersistedState()
    }

    static func makeCoordinator() -> AccountCoordinator {
        let tokenStore = InMemoryTokenStore()
        let mockSession = MockURLProtocol.makeSession()
        let regionConfig = RegionConfig(
            region: .cn,
            appVersion: "1.0.0-staging",
            deviceId: "qa-device-uitest-001"
        )
        let authService = AuthService(
            configuration: AuthServiceConfiguration(
                region: .cn,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: mockSession
            )
        )
        return AccountCoordinator(authService: authService)
    }

    static func makeOnboardingService(tokenStore: TokenStore) -> OnboardingService {
        let regionConfig = RegionConfig(
            region: .cn,
            appVersion: "1.0.0-staging",
            deviceId: "qa-device-uitest-001"
        )
        let mockSession = MockURLProtocol.makeSession()
        return OnboardingService(
            configuration: OnboardingServiceConfiguration(
                region: .cn,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: mockSession
            )
        )
    }

    private static func resetPersistedState() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("com.babycamera.") {
            defaults.removeObject(forKey: key)
        }
    }
}
