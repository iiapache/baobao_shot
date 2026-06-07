import Foundation
import GRDB

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

public enum FeedCacheLimits {
    public static let maxCachedPostsPerFamily = 100
}

/// Offline cache for family feed (post / comment / like tables).
public protocol FeedCacheRepository: Sendable {
    func fetchPosts(familyId: String, limit: Int) async throws -> [PostCacheRecord]
    func savePost(_ post: PostCacheRecord) async throws
    func upsertPosts(_ posts: [PostCacheRecord], familyId: String, keepingLatest maxCount: Int) async throws
    func deletePost(id: String) async throws

    func fetchComments(postId: String) async throws -> [CommentCacheRecord]
    func saveComment(_ comment: CommentCacheRecord) async throws

    func fetchLikes(postId: String) async throws -> [LikeCacheRecord]
    func saveLike(_ like: LikeCacheRecord) async throws
    func deleteLike(postId: String, userId: String) async throws
}

extension PostCacheRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "post_cache"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let familyId = Column(CodingKeys.familyId)
        static let createdAt = Column(CodingKeys.createdAt)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case familyId
        case ownerUserId
        case itemsJSON = "items"
        case caption
        case createdAt
        case syncedAt
    }
}

/// GRDB-backed feed post cache (T5.11 — 最近 100 条).
public struct GRDBFeedCacheRepository: FeedCacheRepository {
    private let dbWriter: any DatabaseWriter

    public init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    public func fetchPosts(familyId: String, limit: Int) async throws -> [PostCacheRecord] {
        try await dbWriter.read { db in
            try PostCacheRecord
                .filter(PostCacheRecord.Columns.familyId == familyId)
                .order(PostCacheRecord.Columns.createdAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func savePost(_ post: PostCacheRecord) async throws {
        try await dbWriter.write { db in
            try post.save(db)
        }
    }

    public func upsertPosts(
        _ posts: [PostCacheRecord],
        familyId: String,
        keepingLatest maxCount: Int
    ) async throws {
        guard !posts.isEmpty else { return }

        try await dbWriter.write { db in
            for post in posts {
                try post.save(db)
            }

            let overflow = try PostCacheRecord
                .filter(PostCacheRecord.Columns.familyId == familyId)
                .order(PostCacheRecord.Columns.createdAt.desc)
                .limit(maxCount, offset: maxCount)
                .fetchAll(db)

            for stale in overflow {
                try stale.delete(db)
            }
        }
    }

    public func deletePost(id: String) async throws {
        _ = try await dbWriter.write { db in
            try PostCacheRecord.deleteOne(db, key: id)
        }
    }

    public func fetchComments(postId: String) async throws -> [CommentCacheRecord] {
        try await dbWriter.read { db in
            try CommentCacheRecord
                .filter(Column("postId") == postId)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    public func saveComment(_ comment: CommentCacheRecord) async throws {
        try await dbWriter.write { db in
            try comment.save(db)
        }
    }

    public func fetchLikes(postId: String) async throws -> [LikeCacheRecord] {
        try await dbWriter.read { db in
            try LikeCacheRecord
                .filter(Column("postId") == postId)
                .fetchAll(db)
        }
    }

    public func saveLike(_ like: LikeCacheRecord) async throws {
        try await dbWriter.write { db in
            try like.save(db)
        }
    }

    public func deleteLike(postId: String, userId: String) async throws {
        _ = try await dbWriter.write { db in
            try LikeCacheRecord.deleteOne(db, key: ["postId": postId, "userId": userId])
        }
    }
}

extension CommentCacheRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "comment_cache"
}

extension LikeCacheRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "like_cache"
}
