import BabyCameraNetwork
import XCTest
@testable import BabyCameraAccount

final class MockAppleSignIn: AppleSignInProviding, @unchecked Sendable {
    var credential = AppleSignInCredential(
        identityToken: "identity-token",
        authorizationCode: "auth-code",
        nickname: "测试用户"
    )
    var shouldThrow = false

    func signIn() async throws -> AppleSignInCredential {
        if shouldThrow {
            throw AppleSignInError.invalidCredential
        }
        return credential
    }
}

final class AuthServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeAuthService(tokenStore: TokenStore = InMemoryTokenStore()) -> AuthService {
        AuthService(
            configuration: AuthServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            )
        )
    }

    func testPhoneLoginPersistsTokens() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/auth/phone/login" {
                return MockResponse(statusCode: 200, json: MockServer.loginSuccessJSON())
            }
            return nil
        }

        let tokenStore = InMemoryTokenStore()
        let service = makeAuthService(tokenStore: tokenStore)

        let session = try await service.loginWithPhone(phone: "13800138000", code: "123456")
        XCTAssertEqual(session.userId, "usr_test_001")
        XCTAssertTrue(session.isNewUser)
        XCTAssertEqual(tokenStore.accessToken(), "access_token_initial")
        XCTAssertEqual(tokenStore.refreshToken(), "refresh_token_initial")
    }

    func testAppleLoginPersistsTokens() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/auth/apple" {
                return MockResponse(statusCode: 200, json: MockServer.loginSuccessJSON(userId: "usr_apple"))
            }
            return nil
        }

        let tokenStore = InMemoryTokenStore()
        let service = makeAuthService(tokenStore: tokenStore)

        let session = try await service.loginWithApple(
            AppleSignInCredential(identityToken: "id", authorizationCode: "code")
        )
        XCTAssertEqual(session.userId, "usr_apple")
        XCTAssertNotNil(tokenStore.refreshToken())
    }

    func testRestoreSessionUsesRefreshToken() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/account/me" {
                return MockResponse(statusCode: 200, json: MockServer.meSuccessJSON(userId: "usr_restored"))
            }
            return nil
        }

        let tokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
        let service = makeAuthService(tokenStore: tokenStore)

        let session = try await service.restoreSession()
        XCTAssertEqual(session.userId, "usr_restored")
    }

    func testRestoreSessionWithoutTokenThrows() async {
        let service = makeAuthService(tokenStore: InMemoryTokenStore())

        do {
            _ = try await service.restoreSession()
            XCTFail("expected not authenticated")
        } catch let error as AuthServiceError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testLogoutClearsTokens() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/account/logout" {
                return MockResponse(statusCode: 200, json: MockServer.emptySuccessJSON())
            }
            return nil
        }

        let tokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
        let service = makeAuthService(tokenStore: tokenStore)

        try await service.logout()
        XCTAssertNil(tokenStore.accessToken())
        XCTAssertNil(tokenStore.refreshToken())
    }

    func testDeleteAccountClearsTokens() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/account" {
                return MockResponse(statusCode: 200, json: MockServer.deletionSuccessJSON())
            }
            return nil
        }

        let tokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
        let service = makeAuthService(tokenStore: tokenStore)

        let result = try await service.deleteAccount()
        XCTAssertEqual(result.scheduledAt, "2026-06-13T10:00:00Z")
        XCTAssertNil(tokenStore.refreshToken())
    }
}
