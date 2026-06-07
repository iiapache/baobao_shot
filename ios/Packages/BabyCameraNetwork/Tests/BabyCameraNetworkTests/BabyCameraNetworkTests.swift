import XCTest
@testable import BabyCameraNetwork

private struct AccountMeData: Decodable, Sendable, Equatable {
    let userId: String
    let nickname: String?
}

private enum TestFixtures {
    static let phone = "13800138000"
    static let code = "123456"
    static let region = AppRegion.cn
    static let regionConfig = RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device-id")

    static func makeClient(
        tokenStore: TokenStore = KeychainTokenStore(),
        logging: LoggingInterceptor? = nil
    ) -> APIClient {
        makeAuthenticatedClient(
            region: region,
            tokenStore: tokenStore,
            regionConfig: regionConfig,
            loggingInterceptor: logging,
            session: MockURLProtocol.makeSession()
        )
    }
}

final class AuthAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testPhoneLoginSuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/auth/phone/login")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Region"), "cn")
            return MockResponse(statusCode: 200, json: MockServer.loginSuccessJSON())
        }

        let tokenStore = KeychainTokenStore()
        let client = TestFixtures.makeClient(tokenStore: tokenStore)
        let authAPI = AuthAPI(client: client)

        let result = try await authAPI.phoneLogin(
            phone: TestFixtures.phone,
            code: TestFixtures.code,
            region: TestFixtures.region
        )

        XCTAssertEqual(result.userId, "usr_test_001")
        XCTAssertEqual(result.accessToken, "access_token_initial")
        XCTAssertEqual(result.refreshToken, "refresh_token_initial")
        XCTAssertNil(tokenStore.accessToken())
        XCTAssertNil(tokenStore.refreshToken())
    }

    func testLoginThenProtectedRequest() async throws {
        MockURLProtocol.register { request in
            switch request.url?.path {
            case "/v1/auth/phone/login":
                return MockResponse(statusCode: 200, json: MockServer.loginSuccessJSON())
            case "/v1/account/me":
                let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
                if auth.contains("access_token_initial") {
                    return MockResponse(statusCode: 200, json: MockServer.meSuccessJSON())
                }
                return MockResponse(statusCode: 401, json: MockServer.tokenExpiredJSON())
            default:
                return nil
            }
        }

        let tokenStore = KeychainTokenStore()
        let client = TestFixtures.makeClient(tokenStore: tokenStore)
        let authAPI = AuthAPI(client: client)

        let login = try await authAPI.phoneLogin(
            phone: TestFixtures.phone,
            code: TestFixtures.code,
            region: TestFixtures.region
        )
        tokenStore.save(
            TokenPair(
                accessToken: login.accessToken,
                refreshToken: login.refreshToken
            )
        )

        let me: AccountMeData = try await client.request(
            AnyEncodableEndpoint(path: "/v1/account/me", method: .get)
        )
        XCTAssertEqual(me.userId, "usr_test_001")
    }
}

final class AuthRefreshTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testAutoRefreshOn401() async throws {
        var meCallCount = 0

        MockURLProtocol.register { request in
            switch request.url?.path {
            case "/v1/auth/refresh":
                return MockResponse(statusCode: 200, json: MockServer.refreshSuccessJSON())
            case "/v1/account/me":
                meCallCount += 1
                if meCallCount == 1 {
                    return MockResponse(statusCode: 401, json: MockServer.tokenExpiredJSON())
                }
                let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
                if auth.contains("access_token_refreshed") {
                    return MockResponse(statusCode: 200, json: MockServer.meSuccessJSON())
                }
                return MockResponse(statusCode: 401, json: MockServer.tokenExpiredJSON())
            default:
                return nil
            }
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(
            TokenPair(
                accessToken: "access_token_stale",
                refreshToken: "refresh_token_valid"
            )
        )

        let client = TestFixtures.makeClient(tokenStore: tokenStore)
        let me: AccountMeData = try await client.request(
            AnyEncodableEndpoint(path: "/v1/account/me", method: .get)
        )

        XCTAssertEqual(meCallCount, 2)
        XCTAssertEqual(me.userId, "usr_test_001")
        XCTAssertEqual(tokenStore.accessToken(), "access_token_refreshed")
        XCTAssertEqual(tokenStore.refreshToken(), "refresh_token_rotated")
        XCTAssertTrue(MockURLProtocol.recordedRequests().contains { $0.url?.path == "/v1/auth/refresh" })
    }

    func testRefreshInvalidThrows() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/account/me" {
                return MockResponse(statusCode: 401, json: MockServer.tokenExpiredJSON())
            }
            if request.url?.path == "/v1/auth/refresh" {
                return MockResponse(
                    statusCode: 401,
                    json: """
                    {
                      "code": "AUTH_REFRESH_INVALID",
                      "message": "refresh token invalid",
                      "requestId": "req_refresh_fail"
                    }
                    """
                )
            }
            return nil
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "stale", refreshToken: "invalid"))
        let client = TestFixtures.makeClient(tokenStore: tokenStore)

        do {
            _ = try await client.request(
                AnyEncodableEndpoint(path: "/v1/account/me", method: .get)
            ) as AccountMeData
            XCTFail("expected APIError")
        } catch let error as APIError {
            XCTAssertEqual(error.code, .authRefreshInvalid)
        }
    }
}

final class LoggingRedactionTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testResponseLogRedaction() async throws {
        let logging = LoggingInterceptor(captureForTesting: true)

        MockURLProtocol.register { request in
            if request.url?.path == "/v1/auth/phone/login" {
                return MockResponse(statusCode: 200, json: MockServer.loginSuccessJSON())
            }
            return nil
        }

        let client = TestFixtures.makeClient(logging: logging)
        let authAPI = AuthAPI(client: client)
        _ = try await authAPI.phoneLogin(
            phone: TestFixtures.phone,
            code: TestFixtures.code,
            region: TestFixtures.region
        )

        let messages = logging.capturedMessages()
        XCTAssertFalse(messages.isEmpty)

        for message in messages {
            XCTAssertFalse(message.contains("access_token_initial"))
            XCTAssertFalse(message.contains("refresh_token_initial"))
            XCTAssertFalse(message.contains("Bearer access"))
            XCTAssertFalse(message.contains(TestFixtures.phone))
        }
        XCTAssertTrue(messages.joined().contains("[REDACTED]"))
    }

    func testLogRedactorUnit() {
        let raw = """
        Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.secret
        {"phone":"13800138000","accessToken":"secret-token","refreshToken":"secret-refresh"}
        """
        let redacted = LogRedactor.redact(raw)
        XCTAssertFalse(redacted.contains("secret-token"))
        XCTAssertFalse(redacted.contains("secret-refresh"))
        XCTAssertFalse(redacted.contains("13800138000"))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }

    func testLogRedactorMasksAppleSub() {
        let raw = #"{"appleSub":"000123.abc456def789.1234","accessToken":"tok"}"#
        let redacted = LogRedactor.redact(raw)
        XCTAssertFalse(redacted.contains("000123.abc456def789.1234"))
        XCTAssertTrue(redacted.contains(#""appleSub":"[REDACTED]"#))
    }
}

final class APIErrorTests: XCTestCase {
    func testErrorCodeMapping() {
        XCTAssertEqual(APIErrorCode(rawCode: "AUTH_TOKEN_EXPIRED"), .authTokenExpired)
        XCTAssertEqual(APIErrorCode(rawCode: "SYS_INTERNAL"), .sysInternal)
        XCTAssertEqual(APIErrorCode(rawCode: "UNKNOWN_CODE_XYZ"), .unknown)

        let expired = APIError(code: .authTokenExpired, message: "expired", httpStatusCode: 401)
        XCTAssertTrue(expired.isTokenExpired)
        XCTAssertFalse(expired.requiresReLogin)

        let reLogin = APIError(code: .authRefreshInvalid, message: "invalid", httpStatusCode: 401)
        XCTAssertTrue(reLogin.requiresReLogin)
    }
}
