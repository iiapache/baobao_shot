import Foundation

/// 单条评论（端侧展示 + 缓存）。
public struct FeedComment: Sendable, Equatable, Identifiable {
    public var id: String { commentId }

    public let commentId: String
    public let postId: String
    public let userId: String
    public let text: String
    public let createdAt: String

    public init(
        commentId: String,
        postId: String,
        userId: String,
        text: String,
        createdAt: String
    ) {
        self.commentId = commentId
        self.postId = postId
        self.userId = userId
        self.text = text
        self.createdAt = createdAt
    }
}
