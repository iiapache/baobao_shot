import XCTest
@testable import BabyCameraNetwork

final class EngagementAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testLikePost() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/posts/pst_001/likes")
            return MockResponse(
                statusCode: 200,
                json: """
                {
                  "postId": "pst_001",
                  "userId": "usr_001",
                  "likedAt": "2026-06-06T10:00:00Z"
                }
                """
            )
        }

        let client = makeTestClient()
        let api = EngagementAPI(client: client)
        let result = try await api.like(postId: "pst_001")

        XCTAssertEqual(result.postId, "pst_001")
        XCTAssertEqual(result.userId, "usr_001")
    }

    func testCreateCommentWithMentions() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/posts/pst_001/comments")
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("mentionUserIds"))
            XCTAssertTrue(body.contains("usr_grandma"))
            return MockResponse(
                statusCode: 200,
                json: """
                {
                  "commentId": "cmt_001",
                  "postId": "pst_001",
                  "userId": "usr_001",
                  "text": "@外婆 好可爱",
                  "createdAt": "2026-06-06T10:05:00Z"
                }
                """
            )
        }

        let client = makeTestClient()
        let api = EngagementAPI(client: client)
        let result = try await api.createComment(
            postId: "pst_001",
            request: CreateCommentRequest(
                text: "@外婆 好可爱",
                mentionUserIds: ["usr_grandma"]
            )
        )

        XCTAssertEqual(result.commentId, "cmt_001")
        XCTAssertEqual(result.text, "@外婆 好可爱")
    }

    func testUnlikePost() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            return MockResponse(
                statusCode: 200,
                json: """
                {
                  "postId": "pst_001",
                  "userId": "usr_001",
                  "removed": true
                }
                """
            )
        }

        let client = makeTestClient()
        let api = EngagementAPI(client: client)
        let result = try await api.unlike(postId: "pst_001")
        XCTAssertTrue(result.removed)
    }

    private func makeTestClient() -> APIClient {
        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        return makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
    }
}
