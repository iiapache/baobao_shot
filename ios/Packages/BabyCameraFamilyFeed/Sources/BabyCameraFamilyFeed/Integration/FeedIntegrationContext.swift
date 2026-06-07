import BabyCameraNetwork
import Database
import Foundation

/// T5.19 联调上下文：聚合 feed-svc 相关的 REST + 本地缓存 + WebSocket 依赖。
public struct FeedIntegrationContext: Sendable {
    public let familyId: String
    public let currentUserId: String
    public let postService: any PostServing
    public let feedService: any FeedServing
    public let engagementService: any EngagementServing
    public let cacheRepository: any FeedCacheRepository
    public let webSocket: (any FeedWebSocketConnecting)?
    public let accessTokenProvider: (@Sendable () async -> String?)?

    public init(
        familyId: String,
        currentUserId: String,
        postService: any PostServing,
        feedService: any FeedServing,
        engagementService: any EngagementServing,
        cacheRepository: any FeedCacheRepository,
        webSocket: (any FeedWebSocketConnecting)? = nil,
        accessTokenProvider: (@Sendable () async -> String?)? = nil
    ) {
        self.familyId = familyId
        self.currentUserId = currentUserId
        self.postService = postService
        self.feedService = feedService
        self.engagementService = engagementService
        self.cacheRepository = cacheRepository
        self.webSocket = webSocket
        self.accessTokenProvider = accessTokenProvider
    }
}
