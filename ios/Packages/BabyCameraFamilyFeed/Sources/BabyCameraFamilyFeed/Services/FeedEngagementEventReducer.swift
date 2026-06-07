import BabyCameraNetwork
import Foundation

/// 将 WebSocket 增量事件合并到端侧互动状态。
public enum FeedEngagementEventReducer {
    public static func apply(
        event: FeedEngagementRemoteEvent,
        to state: FeedEngagementState,
        currentUserId: String,
        isViewingPost: Bool
    ) -> FeedEngagementState {
        var next = state

        switch event {
        case let .likeAdded(_, _, userId, _):
            if userId == currentUserId {
                if !next.likedByCurrentUser {
                    next.likedByCurrentUser = true
                    next.likeCount += 1
                }
            } else {
                next.likeCount += 1
                if !isViewingPost {
                    next.unreadCount += 1
                }
            }

        case let .likeRemoved(_, _, userId):
            if userId == currentUserId {
                if next.likedByCurrentUser {
                    next.likedByCurrentUser = false
                    next.likeCount = max(0, next.likeCount - 1)
                }
            } else {
                next.likeCount = max(0, next.likeCount - 1)
            }

        case let .commentAdded(_, postId, userId, commentId, text, createdAt):
            guard !next.comments.contains(where: { $0.commentId == commentId }) else {
                return next
            }
            next.comments.append(
                FeedComment(
                    commentId: commentId,
                    postId: postId,
                    userId: userId,
                    text: text,
                    createdAt: createdAt
                )
            )
            next.commentCount += 1
            if userId != currentUserId, !isViewingPost {
                next.unreadCount += 1
            }

        case let .commentRemoved(_, _, _, commentId):
            let before = next.comments.count
            next.comments.removeAll { $0.commentId == commentId }
            let removed = before - next.comments.count
            next.commentCount = max(0, next.commentCount - removed)
        }

        return next
    }

    public static func markRead(_ state: FeedEngagementState) -> FeedEngagementState {
        var next = state
        next.unreadCount = 0
        return next
    }
}
