import BabyCameraNetwork
import XCTest
@testable import BabyCameraFamilyFeed

final class FeedEngagementEventReducerTests: XCTestCase {
    func testLikeAddedIncrementsUnreadForOtherUser() {
        let state = FeedEngagementEventReducer.apply(
            event: .likeAdded(
                familyId: "fam_1",
                postId: "pst_1",
                userId: "usr_other",
                likedAt: "2026-06-06T10:00:00Z"
            ),
            to: .empty,
            currentUserId: "usr_me",
            isViewingPost: false
        )

        XCTAssertEqual(state.likeCount, 1)
        XCTAssertEqual(state.unreadCount, 1)
        XCTAssertFalse(state.likedByCurrentUser)
    }

    func testCommentAddedDoesNotIncrementUnreadWhenViewing() {
        let state = FeedEngagementEventReducer.apply(
            event: .commentAdded(
                familyId: "fam_1",
                postId: "pst_1",
                userId: "usr_other",
                commentId: "cmt_1",
                text: "赞",
                createdAt: "2026-06-06T10:00:00Z"
            ),
            to: .empty,
            currentUserId: "usr_me",
            isViewingPost: true
        )

        XCTAssertEqual(state.commentCount, 1)
        XCTAssertEqual(state.unreadCount, 0)
    }

    func testMarkReadClearsUnread() {
        var state = FeedEngagementState(likeCount: 2, unreadCount: 3)
        state = FeedEngagementEventReducer.markRead(state)
        XCTAssertEqual(state.unreadCount, 0)
        XCTAssertEqual(state.likeCount, 2)
    }
}
