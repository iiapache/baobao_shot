import XCTest
@testable import BabyCameraNetwork

final class AccountAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testAppleLoginSuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/auth/apple")
            return MockResponse(statusCode: 200, json: MockServer.loginSuccessJSON(userId: "usr_apple_001"))
        }

        let client = makeAnonymousClient(session: MockURLProtocol.makeSession())
        let authAPI = AuthAPI(client: client)

        let result = try await authAPI.appleLogin(
            identityToken: "identity-token",
            authorizationCode: "auth-code",
            nickname: "豆豆妈",
            region: .cn
        )

        XCTAssertEqual(result.userId, "usr_apple_001")
        XCTAssertEqual(result.accessToken, "access_token_initial")
    }

    func testSendPhoneCodeSuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/phone/code")
            return MockResponse(statusCode: 200, json: MockServer.emptySuccessJSON())
        }

        let client = makeAnonymousClient(session: MockURLProtocol.makeSession())
        let authAPI = AuthAPI(client: client)

        try await authAPI.sendPhoneCode(phone: "13800138000")
    }

    func testLogoutClearsSessionOnServer() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/account/logout" {
                XCTAssertEqual(request.httpMethod, "POST")
                let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
                XCTAssertTrue(auth.contains("access_token_initial"))
                return MockResponse(statusCode: 200, json: MockServer.emptySuccessJSON(requestId: "req_logout"))
            }
            return nil
        }

        let tokenStore = InMemoryTokenStore(
            access: "access_token_initial",
            refresh: "refresh_token_initial"
        )
        let client = makeAuthenticatedClient(
            tokenStore: tokenStore,
            session: MockURLProtocol.makeSession()
        )
        let accountAPI = AccountAPI(client: client)

        try await accountAPI.logout()
    }

    func testDeleteAccountSuccess() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/account" {
                XCTAssertEqual(request.httpMethod, "DELETE")
                return MockResponse(statusCode: 200, json: MockServer.deletionSuccessJSON())
            }
            return nil
        }

        let tokenStore = InMemoryTokenStore(access: "access_token_initial", refresh: "refresh_token_initial")
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let accountAPI = AccountAPI(client: client)

        let result = try await accountAPI.deleteAccount()
        XCTAssertEqual(result.requestedAt, "2026-06-06T10:00:00Z")
        XCTAssertEqual(result.scheduledAt, "2026-06-13T10:00:00Z")
    }
}
