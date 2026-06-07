import Foundation

public enum FeedWebSocketOp: String, Sendable, Codable {
    case subscribe
    case event
    case ping
    case pong
    case error
}

public enum FeedWebSocketEventKind: String, Sendable, Codable {
    case likeAdded = "like_added"
    case likeRemoved = "like_removed"
    case commentAdded = "comment_added"
    case commentRemoved = "comment_removed"
}

public struct FeedWebSocketClientMessage: Encodable, Sendable, Equatable {
    public let op: FeedWebSocketOp
    public let familyIds: [String]?

    public init(op: FeedWebSocketOp, familyIds: [String]? = nil) {
        self.op = op
        self.familyIds = familyIds
    }

    public static func subscribe(familyIds: [String]) -> FeedWebSocketClientMessage {
        FeedWebSocketClientMessage(op: .subscribe, familyIds: familyIds)
    }

    public static let pong = FeedWebSocketClientMessage(op: .pong)
}

public struct FeedWebSocketServerMessage: Decodable, Sendable, Equatable {
    public let op: FeedWebSocketOp
    public let kind: FeedWebSocketEventKind?
    public let familyId: String?
    public let postId: String?
    public let userId: String?
    public let commentId: String?
    public let text: String?
    public let likedAt: String?
    public let createdAt: String?
    public let code: String?
    public let message: String?
}

public enum FeedEngagementRemoteEvent: Sendable, Equatable {
    case likeAdded(familyId: String, postId: String, userId: String, likedAt: String)
    case likeRemoved(familyId: String, postId: String, userId: String)
    case commentAdded(
        familyId: String,
        postId: String,
        userId: String,
        commentId: String,
        text: String,
        createdAt: String
    )
    case commentRemoved(familyId: String, postId: String, userId: String, commentId: String)

    public init?(message: FeedWebSocketServerMessage) {
        guard message.op == .event,
              let kind = message.kind,
              let familyId = message.familyId,
              let postId = message.postId,
              let userId = message.userId
        else {
            return nil
        }

        switch kind {
        case .likeAdded:
            guard let likedAt = message.likedAt else { return nil }
            self = .likeAdded(familyId: familyId, postId: postId, userId: userId, likedAt: likedAt)
        case .likeRemoved:
            self = .likeRemoved(familyId: familyId, postId: postId, userId: userId)
        case .commentAdded:
            guard let commentId = message.commentId,
                  let text = message.text,
                  let createdAt = message.createdAt
            else { return nil }
            self = .commentAdded(
                familyId: familyId,
                postId: postId,
                userId: userId,
                commentId: commentId,
                text: text,
                createdAt: createdAt
            )
        case .commentRemoved:
            guard let commentId = message.commentId else { return nil }
            self = .commentRemoved(
                familyId: familyId,
                postId: postId,
                userId: userId,
                commentId: commentId
            )
        }
    }
}
