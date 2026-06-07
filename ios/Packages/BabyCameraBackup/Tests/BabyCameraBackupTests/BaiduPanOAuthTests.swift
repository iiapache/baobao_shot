import XCTest
@testable import BabyCameraBackup

final class BaiduPanOAuthConfigurationTests: XCTestCase {
    func testResolveModeDefaultsToStub() {
        XCTAssertEqual(
            BaiduPanOAuthConfiguration.resolveMode(forceStub: false, useLiveOAuthOverride: nil),
            .stub
        )
    }

    func testResolveModeForceStub() {
        XCTAssertEqual(
            BaiduPanOAuthConfiguration.resolveMode(forceStub: true, useLiveOAuthOverride: true),
            .stub
        )
    }

    func testResolveModeLiveOverride() {
        XCTAssertEqual(
            BaiduPanOAuthConfiguration.resolveMode(forceStub: false, useLiveOAuthOverride: true),
            .live
        )
    }

    func testCallbackURLScheme() {
        XCTAssertEqual(
            BaiduPanOAuthConfiguration.callbackURLScheme(for: "babycamera://oauth/baidu"),
            "babycamera"
        )
    }

    func testMakeAuthorizeURLContainsRequiredQueryItems() {
        let url = BaiduPanOAuthConfiguration.makeAuthorizeURL(
            clientID: "test-client",
            redirectURI: "babycamera://oauth/baidu",
            state: "state-123"
        )
        XCTAssertNotNil(url)
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let names = Set((components?.queryItems ?? []).map(\.name))
        XCTAssertTrue(names.contains("response_type"))
        XCTAssertTrue(names.contains("client_id"))
        XCTAssertTrue(names.contains("redirect_uri"))
        XCTAssertTrue(names.contains("scope"))
        XCTAssertTrue(names.contains("state"))
    }

    func testReadsConfigurationFromInfoPlist() throws {
        let bundle = try makeBundle(
            useLiveOAuth: "YES",
            clientID: "plist-client",
            redirectURI: "babycamera://oauth/baidu",
            clientSecret: "plist-secret"
        )
        XCTAssertTrue(BaiduPanOAuthConfiguration.useLiveOAuthFromInfoPlist(bundle: bundle))
        XCTAssertEqual(BaiduPanOAuthConfiguration.clientIDFromInfoPlist(bundle: bundle), "plist-client")
        XCTAssertEqual(
            BaiduPanOAuthConfiguration.redirectURIFromInfoPlist(bundle: bundle),
            "babycamera://oauth/baidu"
        )
        XCTAssertEqual(BaiduPanOAuthConfiguration.clientSecretFromInfoPlist(bundle: bundle), "plist-secret")
    }

    private func makeBundle(
        useLiveOAuth: String,
        clientID: String,
        redirectURI: String,
        clientSecret: String
    ) throws -> Bundle {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("baidu-oauth-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let plistURL = directory.appendingPathComponent("Info.plist")
        let plist: [String: Any] = [
            BaiduPanOAuthConfiguration.useLiveOAuthInfoPlistKey: useLiveOAuth,
            BaiduPanOAuthConfiguration.clientIDInfoPlistKey: clientID,
            BaiduPanOAuthConfiguration.redirectURIInfoPlistKey: redirectURI,
            BaiduPanOAuthConfiguration.clientSecretInfoPlistKey: clientSecret,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)
        return Bundle(url: directory)!
    }
}

final class LiveBaiduPanOAuthServiceTests: XCTestCase {
    func testParseAuthorizationCodeSuccess() throws {
        let url = URL(string: "babycamera://oauth/baidu?code=abc123&state=state-1")!
        let code = try LiveBaiduPanOAuthService.parseAuthorizationCode(from: url, expectedState: "state-1")
        XCTAssertEqual(code, "abc123")
    }

    func testParseAuthorizationCodeRejectsStateMismatch() {
        let url = URL(string: "babycamera://oauth/baidu?code=abc&state=wrong")!
        XCTAssertThrowsError(
            try LiveBaiduPanOAuthService.parseAuthorizationCode(from: url, expectedState: "expected")
        ) { error in
            guard case BaiduPanProviderError.authorizationFailed(let message) = error else {
                return XCTFail("unexpected error \(error)")
            }
            XCTAssertEqual(message, "oauth state mismatch")
        }
    }

    func testParseAuthorizationCodeSurfacesProviderError() {
        let url = URL(string: "babycamera://oauth/baidu?error=access_denied&error_description=cancelled")!
        XCTAssertThrowsError(
            try LiveBaiduPanOAuthService.parseAuthorizationCode(from: url, expectedState: "any")
        ) { error in
            guard case BaiduPanProviderError.authorizationFailed(let message) = error else {
                return XCTFail("unexpected error \(error)")
            }
            XCTAssertEqual(message, "cancelled")
        }
    }

    func testAuthorizeRequiresClientSecret() async {
        let service = LiveBaiduPanOAuthService(
            clientID: "client",
            redirectURI: "babycamera://oauth/baidu",
            clientSecret: nil
        )
        do {
            _ = try await service.authorize()
            XCTFail("expected missing secret error")
        } catch let error as BaiduPanProviderError {
            guard case .authorizationFailed(let message) = error else {
                return XCTFail("unexpected error case")
            }
            XCTAssertTrue(message.contains("BaiduPanClientSecret"))
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }
}

final class BaiduPanProviderFactoryTests: XCTestCase {
    func testFactoryStubModeUsesInMemoryTokenStore() {
        let provider = BaiduPanProviderFactory.make(forceStub: true)
        XCTAssertEqual(provider.kind, .baiduPan)
        XCTAssertNil(provider.currentCredentials())
    }
}

private final class OAuthTestTransport: BaiduPanHTTPTransport, @unchecked Sendable {
    var responses: [String: (Data, HTTPURLResponse)] = [:]

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url?.absoluteString,
              let response = responses[url]
        else {
            throw BaiduPanProviderError.uploadFailed("unexpected request")
        }
        return response
    }
}

final class BaiduPanOAuthTokenClientTests: XCTestCase {
    func testExchangeAuthorizationCodeParsesTokenResponse() async throws {
        let transport = OAuthTestTransport()
        transport.responses["https://openapi.baidu.com/oauth/2.0/token"] = (
            """
            {
              "access_token": "access-1",
              "refresh_token": "refresh-1",
              "expires_in": 3600,
              "scope": "basic netdisk"
            }
            """.data(using: .utf8)!,
            HTTPURLResponse(
                url: URL(string: "https://openapi.baidu.com/oauth/2.0/token")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let client = URLSessionBaiduPanOAuthTokenClient(transport: transport)
        let token = try await client.exchangeAuthorizationCode(
            code: "code-1",
            clientID: "client",
            clientSecret: "secret",
            redirectURI: "babycamera://oauth/baidu"
        )

        XCTAssertEqual(token.accessToken, "access-1")
        XCTAssertEqual(token.refreshToken, "refresh-1")
        XCTAssertEqual(token.expiresIn, 3600)
    }
}
