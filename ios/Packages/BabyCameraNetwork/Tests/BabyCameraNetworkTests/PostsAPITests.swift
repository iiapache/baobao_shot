import XCTest
@testable import BabyCameraNetwork

final class PostsAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testCreatePost() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/posts")
            return MockResponse(statusCode: 200, json: MockServer.postCreateSuccessJSON(postId: "pst_feed_001"))
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = PostsAPI(client: client)

        let result = try await api.create(
            PostCreateRequest(
                familyId: "fam_test001",
                babyIds: ["bb_test001"],
                caption: "豆豆 · 第 10 天 · 吉卜力风",
                visibility: .family,
                items: [
                    PostCreateItem(
                        kind: .image,
                        objectKey: "family/fam_test001/post/1.heic",
                        width: 1024,
                        height: 1024,
                        deepSynth: true
                    ),
                ]
            )
        )

        XCTAssertEqual(result.postId, "pst_feed_001")
        XCTAssertEqual(result.status, "published")
    }

    func testDeletePost() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/posts/pst_feed_001")
            return MockResponse(statusCode: 200, json: MockServer.postDeleteSuccessJSON(postId: "pst_feed_001"))
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = PostsAPI(client: client)

        let result = try await api.delete(postId: "pst_feed_001")

        XCTAssertEqual(result.postId, "pst_feed_001")
        XCTAssertEqual(result.status, "removed")
    }
}
