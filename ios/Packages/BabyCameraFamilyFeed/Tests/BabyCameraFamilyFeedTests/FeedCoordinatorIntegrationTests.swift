import BabyCameraBaby
import BabyCameraNetwork
import Database
import XCTest
@testable import BabyCameraFamilyFeed

/// T5.19 全链路 mock：发布 → Feed → 点赞评论 → 撤回
@MainActor
final class FeedCoordinatorIntegrationTests: XCTestCase {
    private let familyId = "fam_integration"
    private let userId = "usr_integration"
    private let babyId = "bb_integration"
    private let publishedPostId = "pst_chain_001"

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testFullChainPublishFeedEngageWithdraw() async throws {
        let mockState = FeedMockServerState(
            familyId: familyId,
            userId: userId,
            babyId: babyId,
            publishedPostId: publishedPostId
        )
        mockState.registerHandlers()

        let context = try await makeIntegrationContext()
        let babyEnv = CurrentBabyEnvironment(restorePersistedSelection: false)
        babyEnv.select(babyId: babyId)

        let coordinator = FamilyFeedIntegration.makeFeedCoordinator(
            context: context,
            currentBabyEnvironment: babyEnv
        )
        let feedListVM = coordinator.attachFeedList()

        // 1. 发布
        let composer = makeComposer(context: context)
        let created = try await coordinator.publish(composer: composer)
        XCTAssertEqual(created.postId, publishedPostId)
        XCTAssertEqual(coordinator.lastPublishedPostId, publishedPostId)
        XCTAssertEqual(mockState.createCallCount, 1)

        // 2. Feed 刷新可见新帖
        await feedListVM.reload()
        XCTAssertEqual(feedListVM.posts.map(\.postId), [publishedPostId])
        XCTAssertEqual(mockState.feedListCallCount, 2) // publish reload + explicit reload

        guard let post = feedListVM.posts.first else {
            XCTFail("expected published post in feed")
            return
        }

        // 3. 点赞
        await feedListVM.doubleTapLike(post: post)
        XCTAssertTrue(feedListVM.engagement(for: publishedPostId).likedByCurrentUser)
        XCTAssertEqual(feedListVM.engagement(for: publishedPostId).likeCount, 1)
        XCTAssertEqual(mockState.likeCallCount, 1)

        // 4. 评论
        try await coordinator.submitComment(on: post, text: "好可爱呀")
        XCTAssertEqual(feedListVM.engagement(for: publishedPostId).commentCount, 1)
        XCTAssertEqual(mockState.commentCallCount, 1)

        // 5. 撤回
        let deleted = try await coordinator.withdraw(postId: publishedPostId)
        XCTAssertEqual(deleted.status, "removed")
        XCTAssertEqual(coordinator.lastWithdrawnPostId, publishedPostId)
        XCTAssertEqual(mockState.deleteCallCount, 1)
        XCTAssertTrue(feedListVM.posts.isEmpty)

        // 缓存也应清除
        let cached = try await context.cacheRepository.fetchPosts(familyId: familyId, limit: 10)
        XCTAssertTrue(cached.isEmpty)
    }

    func testWithdrawForbiddenMapsError() async throws {
        MockURLProtocol.register { request in
            if request.httpMethod == "DELETE", request.url?.path.contains("/v1/posts/") == true {
                return MockResponse(
                    statusCode: 403,
                    json: #"{"code":"COMMON_FORBIDDEN","message":"not post owner","requestId":"req_forbid"}"#
                )
            }
            return MockResponse(statusCode: 404, json: #"{"code":"COMMON_NOT_FOUND","message":"missing"}"#)
        }

        let context = try await makeIntegrationContext()
        let coordinator = FamilyFeedIntegration.makeFeedCoordinator(
            context: context,
            currentBabyEnvironment: CurrentBabyEnvironment(restorePersistedSelection: false)
        )

        do {
            _ = try await coordinator.withdraw(postId: "pst_other")
            XCTFail("expected withdrawForbidden")
        } catch let error as FeedCoordinatorError {
            XCTAssertEqual(error, .withdrawForbidden("not post owner"))
        }
    }

    private func makeIntegrationContext() async throws -> FeedIntegrationContext {
        let appDatabase = try AppDatabase.makeInMemory()
        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access_integration", refreshToken: "refresh"))

        return FamilyFeedIntegration.makeContext(
            dependencies: .init(
                appDatabase: appDatabase,
                tokenStore: tokenStore,
                familyId: familyId,
                currentUserId: userId,
                session: MockURLProtocol.makeSession()
            )
        )
    }

    private func makeComposer(context: FeedIntegrationContext) -> PostComposerViewModel {
        var item = PostComposerMediaItem(
            id: "img_chain",
            kind: .image,
            width: 1024,
            height: 1024,
            deepSynth: false
        )
        item.objectKey = "family/\(familyId)/post/chain.heic"

        let composer = FamilyFeedIntegration.makePostComposerViewModel(
            context: context,
            baby: BabyProfile(
                id: babyId,
                familyId: familyId,
                name: "豆豆",
                birthDate: "2024-01-01"
            )
        )
        composer.addImage(item)
        composer.caption = "联调测试动态"
        return composer
    }
}

// MARK: - Stateful mock feed-svc

private final class FeedMockServerState: @unchecked Sendable {
    let familyId: String
    let userId: String
    let babyId: String
    let publishedPostId: String

    private(set) var createCallCount = 0
    private(set) var feedListCallCount = 0
    private(set) var likeCallCount = 0
    private(set) var commentCallCount = 0
    private(set) var deleteCallCount = 0

    private var isWithdrawn = false

    init(familyId: String, userId: String, babyId: String, publishedPostId: String) {
        self.familyId = familyId
        self.userId = userId
        self.babyId = babyId
        self.publishedPostId = publishedPostId
    }

    func registerHandlers() {
        MockURLProtocol.register { [self] request in
            let path = request.url?.path ?? ""
            let method = request.httpMethod ?? ""

            if method == "POST", path == "/v1/posts" {
                createCallCount += 1
                isWithdrawn = false
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.postCreateSuccessJSON(postId: publishedPostId)
                )
            }

            if method == "GET", path == "/v1/feeds/family" {
                feedListCallCount += 1
                if isWithdrawn {
                    return MockResponse(
                        statusCode: 200,
                        json: MockServer.familyFeedListJSON(items: "")
                    )
                }
                let item = """
                      {
                        "postId": "\(publishedPostId)",
                        "familyId": "\(familyId)",
                        "ownerUserId": "\(userId)",
                        "babyIds": ["\(babyId)"],
                        "caption": "联调测试动态",
                        "visibility": "family",
                        "status": "published",
                        "createdAt": "2026-06-06T10:00:00Z",
                        "items": [
                          {
                            "itemId": "pi_chain",
                            "kind": "image",
                            "objectKey": "family/\(familyId)/post/chain.heic",
                            "width": 1024,
                            "height": 1024,
                            "deepSynth": false
                          }
                        ]
                      }
                """
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.familyFeedListJSON(items: item)
                )
            }

            if method == "POST", path == "/v1/posts/\(publishedPostId)/likes" {
                likeCallCount += 1
                return MockResponse(
                    statusCode: 200,
                    json: """
                    {
                      "postId": "\(publishedPostId)",
                      "userId": "\(userId)",
                      "likedAt": "2026-06-06T10:01:00Z"
                    }
                    """
                )
            }

            if method == "POST", path == "/v1/posts/\(publishedPostId)/comments" {
                commentCallCount += 1
                return MockResponse(
                    statusCode: 200,
                    json: """
                    {
                      "commentId": "cmt_chain_001",
                      "postId": "\(publishedPostId)",
                      "userId": "\(userId)",
                      "text": "好可爱呀",
                      "createdAt": "2026-06-06T10:02:00Z"
                    }
                    """
                )
            }

            if method == "DELETE", path == "/v1/posts/\(publishedPostId)" {
                deleteCallCount += 1
                isWithdrawn = true
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.postDeleteSuccessJSON(postId: publishedPostId)
                )
            }

            return MockResponse(
                statusCode: 404,
                json: #"{"code":"COMMON_NOT_FOUND","message":"unhandled \(method) \(path)"}"#
            )
        }
    }
}
