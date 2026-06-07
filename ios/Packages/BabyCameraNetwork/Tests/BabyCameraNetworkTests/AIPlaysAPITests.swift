import XCTest
@testable import BabyCameraNetwork

final class AIPlaysAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testListPlays() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/ai/plays")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Region"), "cn")
            return MockResponse(statusCode: 200, json: MockServer.aiPlaysCatalogJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = AIPlaysAPI(client: client)

        let catalog = try await api.listPlays()
        XCTAssertEqual(catalog.version, "20250606001")
        XCTAssertEqual(catalog.region, "cn")
        XCTAssertEqual(catalog.ttlSeconds, 300)
        XCTAssertEqual(catalog.plays.count, 3)
        XCTAssertEqual(catalog.plays[0].id, "ghibli_kid")
        XCTAssertEqual(catalog.plays[2].durationTiers?.count, 2)
    }
}
