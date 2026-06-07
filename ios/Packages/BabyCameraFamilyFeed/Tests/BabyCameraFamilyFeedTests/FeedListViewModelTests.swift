import BabyCameraBaby
import BabyCameraNetwork
import XCTest
@testable import BabyCameraFamilyFeed

@MainActor
final class FeedListViewModelTests: XCTestCase {
    func testReloadShowsCacheThenNetwork() async throws {
        let service = MockFeedService()
        service.cachedHandler = {
            FamilyFeedPage(
                items: [
                    FeedPost(
                        postId: "pst_cached",
                        familyId: "fam_001",
                        ownerUserId: "usr_001",
                        babyIds: ["bb_001"],
                        caption: "缓存动态",
                        visibility: "family",
                        status: "published",
                        createdAt: "2026-06-06T09:00:00Z",
                        mediaItems: []
                    ),
                ],
                loadedFromCache: true
            )
        }
        service.fetchHandler = { _, _, cursor, _ in
            XCTAssertNil(cursor)
            return FamilyFeedPage(
                items: [
                    FeedPost(
                        postId: "pst_live",
                        familyId: "fam_001",
                        ownerUserId: "usr_001",
                        babyIds: ["bb_001"],
                        caption: "最新动态",
                        visibility: "family",
                        status: "published",
                        createdAt: "2026-06-06T10:00:00Z",
                        mediaItems: []
                    ),
                ],
                nextCursor: "page2"
            )
        }

        let viewModel = makeFeedListViewModel(feedService: service)

        await viewModel.reload()

        XCTAssertEqual(viewModel.posts.map(\.postId), ["pst_live"])
        XCTAssertEqual(service.fetchCallCount, 1)
        XCTAssertFalse(viewModel.isOffline)
    }

    func testOfflineKeepsCachedPosts() async {
        let service = MockFeedService()
        service.cachedHandler = {
            FamilyFeedPage(
                items: [
                    FeedPost(
                        postId: "pst_offline",
                        familyId: "fam_001",
                        ownerUserId: "usr_001",
                        babyIds: [],
                        caption: "离线可看",
                        visibility: "family",
                        status: "published",
                        createdAt: "2026-06-06T10:00:00Z",
                        mediaItems: []
                    ),
                ],
                loadedFromCache: true
            )
        }
        service.fetchHandler = { _, _, _, _ in
            throw APIError(code: .sysInternal, message: "network down", httpStatusCode: 500)
        }

        let viewModel = makeFeedListViewModel(feedService: service)

        await viewModel.reload()

        XCTAssertEqual(viewModel.posts.count, 1)
        XCTAssertTrue(viewModel.isOffline)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testPagination() async {
        let service = MockFeedService()
        service.fetchHandler = { _, _, cursor, _ in
            if cursor == "page2" {
                return FamilyFeedPage(
                    items: [
                        FeedPost(
                            postId: "pst_2",
                            familyId: "fam_001",
                            ownerUserId: "usr_001",
                            babyIds: [],
                            caption: "第二页",
                            visibility: "family",
                            status: "published",
                            createdAt: "2026-06-05T10:00:00Z",
                            mediaItems: []
                        ),
                    ]
                )
            }
            return FamilyFeedPage(
                items: [
                    FeedPost(
                        postId: "pst_1",
                        familyId: "fam_001",
                        ownerUserId: "usr_001",
                        babyIds: [],
                        caption: "第一页",
                        visibility: "family",
                        status: "published",
                        createdAt: "2026-06-06T10:00:00Z",
                        mediaItems: []
                    ),
                ],
                nextCursor: "page2"
            )
        }

        let viewModel = makeFeedListViewModel(feedService: service)

        await viewModel.reload()
        await viewModel.loadMoreIfNeeded(currentPost: viewModel.posts[0])

        XCTAssertEqual(viewModel.posts.count, 2)
        XCTAssertEqual(viewModel.posts[1].postId, "pst_2")
    }
}

@MainActor
private func makeFeedListViewModel(feedService: MockFeedService) -> FeedListViewModel {
    FeedListViewModel(
        familyId: "fam_001",
        currentUserId: "usr_001",
        feedService: feedService,
        engagementService: StubEngagementService(),
        currentBabyEnvironment: CurrentBabyEnvironment(restorePersistedSelection: false)
    )
}

actor StubEngagementService: EngagementServing {
    func loadEngagement(postId: String, currentUserId: String) async throws -> FeedEngagementState { .empty }
    func toggleLike(postId: String, currentUserId: String, currentlyLiked: Bool) async throws -> FeedEngagementState { .empty }
    func createComment(postId: String, currentUserId: String, text: String, mentions: [FeedMentionCandidate]) async throws -> FeedEngagementState { .empty }
    func applyRemoteEvent(_ event: FeedEngagementRemoteEvent, currentUserId: String, isViewingPost: Bool) async throws {}
    func engagementState(for postId: String) async -> FeedEngagementState { .empty }
    func flushOfflineQueue(currentUserId: String) async throws {}
    func offlinePendingCount() async -> Int { 0 }
}

final class MockFeedService: FeedServing, @unchecked Sendable {
    var cachedHandler: (() throws -> FamilyFeedPage)?
    var fetchHandler: ((String, String?, String?, Bool) throws -> FamilyFeedPage)?
    var fetchCallCount = 0

    func cachedPage(familyId: String, babyId: String?) async throws -> FamilyFeedPage {
        if let cachedHandler {
            return try cachedHandler()
        }
        return FamilyFeedPage(items: [])
    }

    func fetchPage(
        familyId: String,
        babyId: String?,
        cursor: String?,
        persistToCache: Bool
    ) async throws -> FamilyFeedPage {
        fetchCallCount += 1
        if let fetchHandler {
            return try fetchHandler(familyId, babyId, cursor, persistToCache)
        }
        return FamilyFeedPage(items: [])
    }
}
