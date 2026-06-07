import XCTest
@testable import BabyCameraNetwork

final class FeedsAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testListFamilyFeed() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/feeds/family")
            XCTAssertEqual(
                URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?
                    .first(where: { $0.name == "familyId" })?.value,
                "fam_test001"
            )
            return MockResponse(statusCode: 200, json: MockServer.familyFeedListJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = FeedsAPI(client: client)

        let result = try await api.listFamily(familyId: "fam_test001")

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].postId, "pst_feed_001")
        XCTAssertEqual(result.items[0].babyIds, ["bb_test001"])
        XCTAssertEqual(result.cacheTtlSeconds, 60)
        XCTAssertNil(result.nextCursor)
    }

    func testListFamilyFeedPagination() async throws {
        MockURLProtocol.register { request in
            let cursor = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "cursor" })?
                .value

            if cursor == "page2" {
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.familyFeedListJSON(
                        items: """
                              {
                                "postId": "pst_feed_002",
                                "familyId": "fam_test001",
                                "ownerUserId": "usr_test001",
                                "babyIds": ["bb_test001"],
                                "caption": "第二页",
                                "visibility": "family",
                                "status": "published",
                                "createdAt": "2026-06-05T10:00:00Z",
                                "items": []
                              }
                        """,
                        nextCursor: nil
                    )
                )
            }

            return MockResponse(
                statusCode: 200,
                json: MockServer.familyFeedListJSON(nextCursor: "page2")
            )
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = FeedsAPI(client: client)

        let page1 = try await api.listFamily(familyId: "fam_test001", limit: 1)
        XCTAssertEqual(page1.nextCursor, "page2")

        let page2 = try await api.listFamily(familyId: "fam_test001", cursor: "page2", limit: 1)
        XCTAssertEqual(page2.items[0].postId, "pst_feed_002")
        XCTAssertNil(page2.nextCursor)
    }
}
