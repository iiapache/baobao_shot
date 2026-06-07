import BabyCameraNetwork
import Database
import XCTest
@testable import BabyCameraFamilyFeed

final class FeedServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testCachedPageReadsLocalPosts() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let cache = appDatabase.makeFeedCacheRepository()
        let post = FeedPost(
            postId: "pst_cached",
            familyId: "fam_001",
            ownerUserId: "usr_001",
            babyIds: ["bb_001"],
            caption: "离线动态",
            visibility: "family",
            status: "published",
            createdAt: "2026-06-06T10:00:00Z",
            mediaItems: []
        )
        try await cache.savePost(try FeedPostCacheMapper.toCacheRecord(post))

        let service = FeedService(
            feedsAPI: FeedsAPI(client: failingClient()),
            cacheRepository: cache
        )

        let page = try await service.cachedPage(familyId: "fam_001", babyId: "bb_001")
        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items[0].postId, "pst_cached")
        XCTAssertTrue(page.loadedFromCache)
    }

    func testFetchFirstPagePersistsAndTrimsTo100() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let cache = appDatabase.makeFeedCacheRepository()

        MockURLProtocol.register { request in
            XCTAssertEqual(request.url?.path, "/v1/feeds/family")
            let items = (1 ... 5).map { index in
                """
                      {
                        "postId": "pst_new_\(index)",
                        "familyId": "fam_001",
                        "ownerUserId": "usr_001",
                        "babyIds": ["bb_001"],
                        "caption": "动态 \(index)",
                        "visibility": "family",
                        "status": "published",
                        "createdAt": "2026-06-0\(index)T10:00:00Z",
                        "items": []
                      }
                """
            }.joined(separator: ",")

            return MockResponse(
                statusCode: 200,
                json: MockServer.familyFeedListJSON(items: items, nextCursor: "more")
            )
        }

        for index in 1 ... 100 {
            let stale = FeedPost(
                postId: "pst_old_\(index)",
                familyId: "fam_001",
                ownerUserId: "usr_001",
                babyIds: ["bb_001"],
                caption: "旧动态",
                visibility: "family",
                status: "published",
                createdAt: "2026-01-\(String(format: "%02d", min(index, 28)))T10:00:00Z",
                mediaItems: []
            )
            try await cache.savePost(try FeedPostCacheMapper.toCacheRecord(stale))
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let service = FeedService(feedsAPI: FeedsAPI(client: client), cacheRepository: cache)

        let page = try await service.fetchPage(familyId: "fam_001", babyId: nil, cursor: nil)
        XCTAssertEqual(page.items.count, 5)
        XCTAssertEqual(page.nextCursor, "more")

        let cached = try await cache.fetchPosts(familyId: "fam_001", limit: 200)
        XCTAssertEqual(cached.count, 100)
        XCTAssertTrue(cached.contains(where: { $0.id == "pst_new_5" }))
        XCTAssertFalse(cached.contains(where: { $0.id == "pst_old_1" }))
    }

    func testBabyFilterOnCachedPage() async throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let cache = appDatabase.makeFeedCacheRepository()

        for (postId, babyIds) in [("pst_a", ["bb_a"]), ("pst_b", ["bb_b"])] {
            let post = FeedPost(
                postId: postId,
                familyId: "fam_001",
                ownerUserId: "usr_001",
                babyIds: babyIds,
                caption: postId,
                visibility: "family",
                status: "published",
                createdAt: "2026-06-06T10:00:00Z",
                mediaItems: []
            )
            try await cache.savePost(try FeedPostCacheMapper.toCacheRecord(post))
        }

        let service = FeedService(
            feedsAPI: FeedsAPI(client: failingClient()),
            cacheRepository: cache
        )

        let page = try await service.cachedPage(familyId: "fam_001", babyId: "bb_a")
        XCTAssertEqual(page.items.map(\.postId), ["pst_a"])
    }

    private func failingClient() -> APIClient {
        makeAuthenticatedClient(session: MockURLProtocol.makeSession())
    }
}
