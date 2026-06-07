import BabyCameraNetwork
import Database
import Foundation

/// `post_cache.items` 列的 JSON 信封：媒体 + 元数据。
struct PostCacheItemsEnvelope: Codable, Equatable, Sendable {
    var babyIds: [String]
    var visibility: String
    var status: String
    var media: [FeedMediaItem]

    init(
        babyIds: [String],
        visibility: String,
        status: String,
        media: [FeedMediaItem]
    ) {
        self.babyIds = babyIds
        self.visibility = visibility
        self.status = status
        self.media = media
    }

    init(post: FeedPost) {
        self.init(
            babyIds: post.babyIds,
            visibility: post.visibility,
            status: post.status,
            media: post.mediaItems
        )
    }
}

enum FeedPostCacheMapper {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()
    private static let isoFormatter = ISO8601DateFormatter()

    static func toCacheRecord(_ post: FeedPost, syncedAt: Int64 = currentUnixTime()) throws -> PostCacheRecord {
        let envelope = PostCacheItemsEnvelope(post: post)
        let itemsJSON = try String(data: encoder.encode(envelope), encoding: .utf8) ?? "[]"
        return PostCacheRecord(
            id: post.postId,
            familyId: post.familyId,
            ownerUserId: post.ownerUserId,
            itemsJSON: itemsJSON,
            caption: post.caption.isEmpty ? nil : post.caption,
            createdAt: unixTime(fromISO: post.createdAt),
            syncedAt: syncedAt
        )
    }

    static func fromCacheRecord(_ record: PostCacheRecord) throws -> FeedPost {
        let data = Data(record.itemsJSON.utf8)
        let envelope = try decoder.decode(PostCacheItemsEnvelope.self, from: data)
        return FeedPost(
            postId: record.id,
            familyId: record.familyId,
            ownerUserId: record.ownerUserId,
            babyIds: envelope.babyIds,
            caption: record.caption ?? "",
            visibility: envelope.visibility,
            status: envelope.status,
            createdAt: isoString(fromUnix: record.createdAt),
            mediaItems: envelope.media
        )
    }

    static func unixTime(fromISO iso: String) -> Int64 {
        if let date = isoFormatter.date(from: iso) {
            return Int64(date.timeIntervalSince1970)
        }
        return 0
    }

    static func isoString(fromUnix unix: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        return isoFormatter.string(from: date)
    }

    static func currentUnixTime() -> Int64 {
        Int64(Date().timeIntervalSince1970)
    }
}
