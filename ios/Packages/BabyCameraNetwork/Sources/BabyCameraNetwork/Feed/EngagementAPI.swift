import Foundation

// MARK: - Models

public struct LikeResponseData: Decodable, Sendable, Equatable {
    public let postId: String
    public let userId: String
    public let likedAt: String
    public let duplicate: Bool?

    public init(postId: String, userId: String, likedAt: String, duplicate: Bool? = nil) {
        self.postId = postId
        self.userId = userId
        self.likedAt = likedAt
        self.duplicate = duplicate
    }
}

public struct UnlikeResponseData: Decodable, Sendable, Equatable {
    public let postId: String
    public let userId: String
    public let removed: Bool

    public init(postId: String, userId: String, removed: Bool) {
        self.postId = postId
        self.userId = userId
        self.removed = removed
    }
}

public struct CreateCommentRequest: Encodable, Sendable, Equatable {
    public let text: String
    public let parentId: String?
    public let mentionUserIds: [String]?

    public init(text: String, parentId: String? = nil, mentionUserIds: [String]? = nil) {
        self.text = text
        self.parentId = parentId
        self.mentionUserIds = mentionUserIds
    }
}

public struct CommentResponseData: Decodable, Sendable, Equatable {
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

public struct DeleteCommentResponseData: Decodable, Sendable, Equatable {
    public let commentId: String
    public let postId: String
    public let removed: Bool

    public init(commentId: String, postId: String, removed: Bool) {
        self.commentId = commentId
        self.postId = postId
        self.removed = removed
    }
}

// MARK: - Endpoint

enum EngagementEndpoint: Endpoint {
    case like(postId: String)
    case unlike(postId: String)
    case createComment(postId: String, request: CreateCommentRequest)
    case deleteComment(postId: String, commentId: String)

    var path: String {
        switch self {
        case let .like(postId):
            return "/v1/posts/\(postId)/likes"
        case let .unlike(postId):
            return "/v1/posts/\(postId)/likes"
        case let .createComment(postId, _):
            return "/v1/posts/\(postId)/comments"
        case let .deleteComment(postId, commentId):
            return "/v1/posts/\(postId)/comments/\(commentId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .like, .createComment:
            return .post
        case .unlike, .deleteComment:
            return .delete
        }
    }

    func encodeBody(with encoder: JSONEncoder) throws -> Data? {
        switch self {
        case .like, .unlike:
            return nil
        case let .createComment(_, request):
            return try encoder.encode(request)
        case .deleteComment:
            return nil
        }
    }
}

// MARK: - API

public struct EngagementAPI: Sendable {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /v1/posts/{postId}/likes
    public func like(postId: String) async throws -> LikeResponseData {
        try await client.request(EngagementEndpoint.like(postId: postId))
    }

    /// DELETE /v1/posts/{postId}/likes
    public func unlike(postId: String) async throws -> UnlikeResponseData {
        try await client.request(EngagementEndpoint.unlike(postId: postId))
    }

    /// POST /v1/posts/{postId}/comments
    public func createComment(postId: String, request: CreateCommentRequest) async throws -> CommentResponseData {
        try await client.request(EngagementEndpoint.createComment(postId: postId, request: request))
    }

    /// DELETE /v1/posts/{postId}/comments/{commentId}
    public func deleteComment(postId: String, commentId: String) async throws -> DeleteCommentResponseData {
        try await client.request(EngagementEndpoint.deleteComment(postId: postId, commentId: commentId))
    }
}
