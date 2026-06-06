import BabyCameraNetwork
import XCTest
@testable import BabyCameraAccount

@MainActor
final class AccountCoordinatorTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeCoordinator(tokenStore: TokenStore = InMemoryTokenStore()) -> AccountCoordinator {
        let authService = AuthService(
            configuration: AuthServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            )
        )
        return AccountCoordinator(authService: authService, appleSignIn: MockAppleSignIn())
    }

    func testBootstrapWithoutTokenShowsLogin() async {
        let coordinator = makeCoordinator()
        await coordinator.bootstrap()
        XCTAssertEqual(coordinator.phase, .login)
        XCTAssertNil(coordinator.session)
    }

    func testBootstrapRestoresSession() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/account/me" {
                return MockResponse(statusCode: 200, json: MockServer.meSuccessJSON(userId: "usr_existing"))
            }
            return nil
        }

        let tokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
        let coordinator = makeCoordinator(tokenStore: tokenStore)

        await coordinator.bootstrap()

        guard case let .authenticated(session) = coordinator.phase else {
            return XCTFail("expected authenticated phase")
        }
        XCTAssertEqual(session.userId, "usr_existing")
        XCTAssertEqual(coordinator.session?.userId, "usr_existing")
    }

    func testHandleAuthenticatedNewUserGoesToOnboarding() {
        let coordinator = makeCoordinator()
        let session = AuthSession(
            userId: "usr_new",
            isNewUser: true,
            profile: nil
        )

        coordinator.handleAuthenticated(session)

        XCTAssertEqual(coordinator.phase, .onboarding(session))
    }

    func testHandleLogoutReturnsToLogin() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/account/logout" {
                return MockResponse(statusCode: 200, json: MockServer.emptySuccessJSON())
            }
            return nil
        }

        let tokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
        let coordinator = makeCoordinator(tokenStore: tokenStore)
        coordinator.handleAuthenticated(
            AuthSession(userId: "usr_1", isNewUser: false, profile: nil)
        )

        await coordinator.handleLogout()

        XCTAssertEqual(coordinator.phase, .login)
        XCTAssertNil(coordinator.session)
        XCTAssertNil(tokenStore.refreshToken())
    }
}
