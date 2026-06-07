import Foundation

/// 单条动态的点赞 / 评论 / 未读状态。
public struct FeedEngagementState: Sendable, Equatable {
    public var likeCount: Int
    public var commentCount: Int
    public var likedByCurrentUser: Bool
    public var unreadCount: Int
    public var comments: [FeedComment]

    public init(
        likeCount: Int = 0,
        commentCount: Int = 0,
        likedByCurrentUser: Bool = false,
        unreadCount: Int = 0,
        comments: [FeedComment] = []
    ) {
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.likedByCurrentUser = likedByCurrentUser
        self.unreadCount = unreadCount
        self.comments = comments
    }

    public static let empty = FeedEngagementState()
}
