import BabyCameraNetwork
import Foundation

/// 家庭圈 Feed 列表项（端侧展示模型）。
public struct FeedPost: Sendable, Equatable, Identifiable {
    public var id: String { postId }

    public let postId: String
    public let familyId: String
    public let ownerUserId: String
    public let babyIds: [String]
    public let caption: String
    public let visibility: String
    public let status: String
    public let createdAt: String
    public let mediaItems: [FeedMediaItem]

    public init(
        postId: String,
        familyId: String,
        ownerUserId: String,
        babyIds: [String],
        caption: String,
        visibility: String,
        status: String,
        createdAt: String,
        mediaItems: [FeedMediaItem]
    ) {
        self.postId = postId
        self.familyId = familyId
        self.ownerUserId = ownerUserId
        self.babyIds = babyIds
        self.caption = caption
        self.visibility = visibility
        self.status = status
        self.createdAt = createdAt
        self.mediaItems = mediaItems
    }

    public init(apiItem: FeedPostItem) {
        self.init(
            postId: apiItem.postId,
            familyId: apiItem.familyId,
            ownerUserId: apiItem.ownerUserId,
            babyIds: apiItem.babyIds,
            caption: apiItem.caption,
            visibility: apiItem.visibility,
            status: apiItem.status,
            createdAt: apiItem.createdAt,
            mediaItems: apiItem.items
        )
    }

    public func matchesBabyFilter(_ babyId: String?) -> Bool {
        guard let babyId, !babyId.isEmpty else { return true }
        return babyIds.isEmpty || babyIds.contains(babyId)
    }
}

public struct FamilyFeedPage: Sendable, Equatable {
    public let items: [FeedPost]
    public let nextCursor: String?
    public let loadedFromCache: Bool

    public init(items: [FeedPost], nextCursor: String? = nil, loadedFromCache: Bool = false) {
        self.items = items
        self.nextCursor = nextCursor
        self.loadedFromCache = loadedFromCache
    }
}
