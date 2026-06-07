import BabyCameraBaby
import BabyCameraNetwork
import XCTest
@testable import BabyCameraFamilyFeed

@MainActor
final class FeedListViewModelEngagementTests: XCTestCase {
    func testDoubleTapLikeUpdatesEngagement() async throws {
        let engagement = MockEngagementService()
        engagement.toggleLikeHandler = { postId, _, currentlyLiked in
            XCTAssertEqual(postId, "pst_1")
            XCTAssertFalse(currentlyLiked)
            return FeedEngagementState(likeCount: 1, likedByCurrentUser: true)
        }

        let viewModel = makeViewModel(engagementService: engagement)
        viewModel.posts = [samplePost(id: "pst_1")]

        await viewModel.doubleTapLike(post: samplePost(id: "pst_1"))

        XCTAssertTrue(viewModel.engagement(for: "pst_1").likedByCurrentUser)
        XCTAssertEqual(viewModel.engagement(for: "pst_1").likeCount, 1)
    }

    func testRemoteCommentIncrementsUnreadBadge() async throws {
        let engagement = MockEngagementService()
        engagement.stateHandler = { _ in
            FeedEngagementState(commentCount: 1, unreadCount: 1)
        }
        let viewModel = makeViewModel(engagementService: engagement)
        viewModel.posts = [samplePost(id: "pst_1")]

        await viewModel.handleRemoteEventForTests(
            .commentAdded(
                familyId: "fam_001",
                postId: "pst_1",
                userId: "usr_other",
                commentId: "cmt_1",
                text: "好可爱",
                createdAt: "2026-06-06T10:00:00Z"
            )
        )

        XCTAssertEqual(viewModel.totalUnreadCount, 1)
        XCTAssertEqual(viewModel.engagement(for: "pst_1").unreadCount, 1)
    }

    func testBeginCommentClearsUnread() async {
        let engagement = MockEngagementService()
        let viewModel = makeViewModel(engagementService: engagement)
        viewModel.posts = [samplePost(id: "pst_1")]
        viewModel.engagementByPostId["pst_1"] = FeedEngagementState(unreadCount: 2)

        viewModel.beginComment(on: samplePost(id: "pst_1"))

        XCTAssertEqual(viewModel.commentComposerPostId, "pst_1")
        XCTAssertEqual(viewModel.engagement(for: "pst_1").unreadCount, 0)
    }

    private func makeViewModel(engagementService: MockEngagementService) -> FeedListViewModel {
        FeedListViewModel(
            familyId: "fam_001",
            currentUserId: "usr_me",
            mentionCandidates: [FeedMentionCandidate(id: "usr_grandma", nickname: "外婆")],
            feedService: MockFeedService(),
            engagementService: engagementService,
            currentBabyEnvironment: CurrentBabyEnvironment(restorePersistedSelection: false)
        )
    }

    private func samplePost(id: String) -> FeedPost {
        FeedPost(
            postId: id,
            familyId: "fam_001",
            ownerUserId: "usr_owner",
            babyIds: [],
            caption: "测试",
            visibility: "family",
            status: "published",
            createdAt: "2026-06-06T10:00:00Z",
            mediaItems: []
        )
    }
}

extension FeedListViewModel {
    fileprivate func handleRemoteEventForTests(_ event: FeedEngagementRemoteEvent) async {
        let postId: String
        switch event {
        case let .likeAdded(_, id, _, _),
             let .likeRemoved(_, id, _),
             let .commentAdded(_, id, _, _, _, _),
             let .commentRemoved(_, id, _, _):
            postId = id
        }

        let isViewing = commentComposerPostId == postId
        try? await engagementService.applyRemoteEvent(
            event,
            currentUserId: currentUserId,
            isViewingPost: isViewing
        )
        let state = await engagementService.engagementState(for: postId)
        engagementByPostId[postId] = state
        totalUnreadCount = engagementByPostId.values.reduce(0) { $0 + $1.unreadCount }
    }
}

actor MockEngagementService: EngagementServing {
    var toggleLikeHandler: ((String, String, Bool) throws -> FeedEngagementState)?
    var stateHandler: ((String) -> FeedEngagementState)?

    func loadEngagement(postId: String, currentUserId: String) async throws -> FeedEngagementState {
        _ = currentUserId
        return .empty
    }

    func toggleLike(
        postId: String,
        currentUserId: String,
        currentlyLiked: Bool
    ) async throws -> FeedEngagementState {
        if let toggleLikeHandler {
            return try toggleLikeHandler(postId, currentUserId, currentlyLiked)
        }
        return .empty
    }

    func createComment(
        postId: String,
        currentUserId: String,
        text: String,
        mentions: [FeedMentionCandidate]
    ) async throws -> FeedEngagementState {
        _ = postId
        _ = currentUserId
        _ = text
        _ = mentions
        return .empty
    }

    func applyRemoteEvent(
        _ event: FeedEngagementRemoteEvent,
        currentUserId: String,
        isViewingPost: Bool
    ) async throws {
        _ = event
        _ = currentUserId
        _ = isViewingPost
    }

    func engagementState(for postId: String) async -> FeedEngagementState {
        if let stateHandler {
            return stateHandler(postId)
        }
        return .empty
    }

    func flushOfflineQueue(currentUserId: String) async throws {
        _ = currentUserId
    }

    func offlinePendingCount() async -> Int { 0 }
}
