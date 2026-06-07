import BabyCameraNetwork
import Database
import XCTest
@testable import BabyCameraFamilyFeed

final class EngagementServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testToggleLikePersistsToCache() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            return MockResponse(
                statusCode: 200,
                json: """
                {
                  "postId": "pst_001",
                  "userId": "usr_me",
                  "likedAt": "2026-06-06T10:00:00Z"
                }
                """
            )
        }

        let service = try await makeService()
        let state = try await service.toggleLike(
            postId: "pst_001",
            currentUserId: "usr_me",
            currentlyLiked: false
        )

        XCTAssertTrue(state.likedByCurrentUser)
        XCTAssertEqual(state.likeCount, 1)
    }

    func testOfflineLikeQueuesAndFlushes() async throws {
        MockURLProtocol.register { _ in
            MockResponse(statusCode: 500, json: #"{"code":"SYS_INTERNAL","message":"offline"}"#)
        }

        let service = try await makeService()
        do {
            _ = try await service.toggleLike(
                postId: "pst_offline",
                currentUserId: "usr_me",
                currentlyLiked: false
            )
            XCTFail("expected network error")
        } catch {
            XCTAssertEqual(await service.offlinePendingCount(), 1)
        }

        MockURLProtocol.reset()
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            return MockResponse(
                statusCode: 200,
                json: """
                {
                  "postId": "pst_offline",
                  "userId": "usr_me",
                  "likedAt": "2026-06-06T11:00:00Z"
                }
                """
            )
        }

        try await service.flushOfflineQueue(currentUserId: "usr_me")
        XCTAssertEqual(await service.offlinePendingCount(), 0)
    }

    func testCreateCommentWithMentionUserIds() async throws {
        MockURLProtocol.register { request in
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("usr_grandma"))
            return MockResponse(
                statusCode: 200,
                json: """
                {
                  "commentId": "cmt_001",
                  "postId": "pst_001",
                  "userId": "usr_me",
                  "text": "@外婆 好可爱",
                  "createdAt": "2026-06-06T10:05:00Z"
                }
                """
            )
        }

        let service = try await makeService()
        let state = try await service.createComment(
            postId: "pst_001",
            currentUserId: "usr_me",
            text: "@外婆 好可爱",
            mentions: [FeedMentionCandidate(id: "usr_grandma", nickname: "外婆")]
        )

        XCTAssertEqual(state.commentCount, 1)
        XCTAssertEqual(state.comments.first?.text, "@外婆 好可爱")
    }

    private func makeService() async throws -> EngagementService {
        let appDatabase = try AppDatabase.makeInMemory()
        let cache = appDatabase.makeFeedCacheRepository()
        let settings = appDatabase.makeSettingRepository()
        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        return EngagementService(
            engagementAPI: EngagementAPI(client: client),
            cacheRepository: cache,
            offlineQueue: EngagementOfflineQueue(familyId: "fam_001", settingRepository: settings)
        )
    }
}
