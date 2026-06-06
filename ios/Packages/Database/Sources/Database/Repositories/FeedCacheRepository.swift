import Foundation

public struct PostCacheRecord: Sendable, Equatable {
    public var id: String
    public var familyId: String
    public var ownerUserId: String
    public var itemsJSON: String
    public var caption: String?
    public var createdAt: Int64
    public var syncedAt: Int64?

    public init(
        id: String,
        familyId: String,
        ownerUserId: String,
        itemsJSON: String,
        caption: String? = nil,
        createdAt: Int64,
        syncedAt: Int64? = nil
    ) {
        self.id = id
        self.familyId = familyId
        self.ownerUserId = ownerUserId
        self.itemsJSON = itemsJSON
        self.caption = caption
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}

public struct CommentCacheRecord: Sendable, Equatable {
    public var id: String
    public var postId: String
    public var userId: String
    public var text: String
    public var createdAt: Int64

    public init(id: String, postId: String, userId: String, text: String, createdAt: Int64) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.text = text
        self.createdAt = createdAt
    }
}

public struct LikeCacheRecord: Sendable, Equatable {
    public var postId: String
    public var userId: String
    public var likedAt: Int64

    public init(postId: String, userId: String, likedAt: Int64) {
        self.postId = postId
        self.userId = userId
        self.likedAt = likedAt
    }
}

/// Offline cache for family feed (post / comment / like tables).
public protocol FeedCacheRepository: Sendable {
    func fetchPosts(familyId: String, limit: Int) async throws -> [PostCacheRecord]
    func savePost(_ post: PostCacheRecord) async throws
    func deletePost(id: String) async throws

    func fetchComments(postId: String) async throws -> [CommentCacheRecord]
    func saveComment(_ comment: CommentCacheRecord) async throws

    func fetchLikes(postId: String) async throws -> [LikeCacheRecord]
    func saveLike(_ like: LikeCacheRecord) async throws
    func deleteLike(postId: String, userId: String) async throws
}
