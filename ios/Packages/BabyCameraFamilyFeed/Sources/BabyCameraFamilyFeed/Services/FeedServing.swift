import BabyCameraNetwork
import Database
import Foundation

public enum FeedServiceError: Error, Equatable, Sendable {
    case familyIdMissing
}

/// 家庭圈 Feed 列表服务：离线优先 + 分页 + `post_cache` 最近 100 条。
public protocol FeedServing: Sendable {
    func cachedPage(familyId: String, babyId: String?) async throws -> FamilyFeedPage
    func fetchPage(
        familyId: String,
        babyId: String?,
        cursor: String?,
        persistToCache: Bool
    ) async throws -> FamilyFeedPage
}

public struct FeedService: FeedServing {
    public static let cacheLimit = FeedCacheLimits.maxCachedPostsPerFamily

    private let feedsAPI: FeedsAPI
    private let cacheRepository: any FeedCacheRepository
    private let pageSize: Int

    public init(
        feedsAPI: FeedsAPI,
        cacheRepository: any FeedCacheRepository,
        pageSize: Int = FeedsAPI.defaultPageSize
    ) {
        self.feedsAPI = feedsAPI
        self.cacheRepository = cacheRepository
        self.pageSize = pageSize
    }

    public func cachedPage(familyId: String, babyId: String?) async throws -> FamilyFeedPage {
        let records = try await cacheRepository.fetchPosts(
            familyId: familyId,
            limit: Self.cacheLimit
        )
        let posts = try records.map(FeedPostCacheMapper.fromCacheRecord)
        let filtered = posts.filter { $0.matchesBabyFilter(babyId) }
        return FamilyFeedPage(items: filtered, nextCursor: nil, loadedFromCache: true)
    }

    public func fetchPage(
        familyId: String,
        babyId: String?,
        cursor: String?,
        persistToCache: Bool = true
    ) async throws -> FamilyFeedPage {
        let trimmedFamilyId = familyId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFamilyId.isEmpty else {
            throw FeedServiceError.familyIdMissing
        }

        let response = try await feedsAPI.listFamily(
            familyId: trimmedFamilyId,
            cursor: cursor,
            limit: pageSize
        )
        let posts = response.items.map(FeedPost.init(apiItem:))
        let filtered = posts.filter { $0.matchesBabyFilter(babyId) }

        if persistToCache, cursor == nil {
            let records = try posts.map { try FeedPostCacheMapper.toCacheRecord($0) }
            try await cacheRepository.upsertPosts(
                records,
                familyId: trimmedFamilyId,
                keepingLatest: Self.cacheLimit
            )
        }

        return FamilyFeedPage(
            items: filtered,
            nextCursor: response.nextCursor,
            loadedFromCache: false
        )
    }
}
