import BabyCameraBackup
import BabyCameraNetwork
import XCTest
@testable import BabyCameraSettings

final class BackupTargetsBaiduOAuthTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testBindBaiduPanRunsOAuthAndPostsCredentials() async throws {
        var capturedBody: Data?
        MockURLProtocol.register { request in
            if request.httpMethod == "POST", request.url?.path == "/v1/backup/providers" {
                capturedBody = request.httpBody
                return MockResponse(statusCode: 200, json: MockServer.backupProviderJSON(kind: "baidu_pan"))
            }
            return MockResponse(statusCode: 404, json: ["error": "not found"])
        }

        let oauth = StubBaiduPanOAuthService(
            credentials: BaiduPanCredentials(
                accessToken: "baidu-live-token",
                refreshToken: "baidu-live-refresh",
                expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
                providerAccountId: "uid-42"
            )
        )
        let provider = BaiduPanProvider.stub(oauth: oauth, tokenStore: InMemoryBaiduPanTokenStore())
        let service = makeService(baiduPanProvider: provider)

        let result = try await service.bindTarget(.baiduPan)

        XCTAssertEqual(result.kind, "baidu_pan")
        XCTAssertEqual(provider.currentCredentials()?.accessToken, "baidu-live-token")

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any])
        XCTAssertEqual(json["accessToken"] as? String, "baidu-live-token")
        XCTAssertEqual(json["refreshToken"] as? String, "baidu-live-refresh")
        XCTAssertEqual(json["providerAccountId"] as? String, "uid-42")
        XCTAssertEqual((json["metadata"] as? [String: String])?["oauth"], "baidu_pan")
    }

    func testUnbindBaiduPanRevokesLocalToken() async throws {
        MockURLProtocol.register { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/v1/backup/providers"):
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.backupProviderListJSON(items: [("bkp_baidu", "baidu_pan")])
                )
            case ("DELETE", "/v1/backup/providers/bkp_baidu"):
                return MockResponse(statusCode: 200, json: ["id": "bkp_baidu"])
            default:
                return MockResponse(statusCode: 404, json: ["error": "not found"])
            }
        }

        let tokenStore = InMemoryBaiduPanTokenStore(
            credentials: BaiduPanCredentials(accessToken: "stored-token")
        )
        let provider = BaiduPanProvider.stub(tokenStore: tokenStore)
        let service = makeService(baiduPanProvider: provider)

        try await service.unbindTarget(.baiduPan)

        XCTAssertNil(provider.currentCredentials())
    }

    func testBindICloudStillUsesDeviceLocalToken() async throws {
        var capturedBody: Data?
        MockURLProtocol.register { request in
            if request.httpMethod == "POST", request.url?.path == "/v1/backup/providers" {
                capturedBody = request.httpBody
                return MockResponse(statusCode: 200, json: MockServer.backupProviderJSON(kind: "icloud"))
            }
            return MockResponse(statusCode: 404, json: ["error": "not found"])
        }

        let service = makeService(baiduPanProvider: BaiduPanProvider.stub())
        _ = try await service.bindTarget(.iCloud)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: Any])
        XCTAssertEqual(json["accessToken"] as? String, "device-local")
        XCTAssertEqual(json["kind"] as? String, "icloud")
    }

    private func makeService(baiduPanProvider: BaiduPanProvider) -> BackupTargetsService {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(
            tokenStore: tokenStore,
            session: MockURLProtocol.makeSession()
        )
        return BackupTargetsService(api: BackupAPI(client: client), baiduPanProvider: baiduPanProvider)
    }
}
