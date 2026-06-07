import BabyCameraBaby
import BabyCameraNetwork
import Database
import Foundation

/// T5.19 端 ↔ feed-svc 接线工厂：从 App 依赖注入 Post / Feed / Engagement 服务与 ViewModel。
public enum FamilyFeedIntegration {
    public struct Dependencies: Sendable {
        public let appDatabase: AppDatabase
        public let tokenStore: TokenStore
        public let familyId: String
        public let currentUserId: String
        public let region: AppRegion
        public let session: URLSession
        public let webSocket: (any FeedWebSocketConnecting)?

        public init(
            appDatabase: AppDatabase,
            tokenStore: TokenStore = KeychainTokenStore(),
            familyId: String,
            currentUserId: String,
            region: AppRegion = .cn,
            session: URLSession = .shared,
            webSocket: (any FeedWebSocketConnecting)? = nil
        ) {
            self.appDatabase = appDatabase
            self.tokenStore = tokenStore
            self.familyId = familyId
            self.currentUserId = currentUserId
            self.region = region
            self.session = session
            self.webSocket = webSocket
        }
    }

    /// 装配 feed-svc 全链路服务上下文（REST + 本地缓存 + 可选 WS）。
    public static func makeContext(dependencies: Dependencies) -> FeedIntegrationContext {
        let client = makeAuthenticatedClient(
            region: dependencies.region,
            tokenStore: dependencies.tokenStore,
            session: dependencies.session
        )
        let cacheRepository = dependencies.appDatabase.makeFeedCacheRepository()
        let settingRepository = dependencies.appDatabase.makeSettingRepository()

        let postService = PostService(
            postsAPI: PostsAPI(client: client),
            cacheRepository: cacheRepository
        )
        let feedService = FeedService(
            feedsAPI: FeedsAPI(client: client),
            cacheRepository: cacheRepository
        )
        let engagementService = EngagementService(
            engagementAPI: EngagementAPI(client: client),
            cacheRepository: cacheRepository,
            offlineQueue: EngagementOfflineQueue(
                familyId: dependencies.familyId,
                settingRepository: settingRepository
            )
        )

        let tokenStore = dependencies.tokenStore
        let accessTokenProvider: @Sendable () async -> String? = {
            tokenStore.accessToken()
        }

        return FeedIntegrationContext(
            familyId: dependencies.familyId,
            currentUserId: dependencies.currentUserId,
            postService: postService,
            feedService: feedService,
            engagementService: engagementService,
            cacheRepository: cacheRepository,
            webSocket: dependencies.webSocket,
            accessTokenProvider: accessTokenProvider
        )
    }

    @MainActor
    public static func makeFeedCoordinator(
        context: FeedIntegrationContext,
        currentBabyEnvironment: CurrentBabyEnvironment,
        mentionCandidates: [FeedMentionCandidate] = []
    ) -> FeedCoordinator {
        FeedCoordinator(
            context: context,
            currentBabyEnvironment: currentBabyEnvironment,
            mentionCandidates: mentionCandidates
        )
    }

    @MainActor
    public static func makePostComposerViewModel(
        context: FeedIntegrationContext,
        baby: BabyProfile,
        aiPlayName: String? = nil,
        aiPlayId: String? = nil,
        isSubscribed: Bool = false,
        initialCaption: String? = nil,
        visibility: PostVisibility = .family,
        captionService: (any CaptionServing)? = nil
    ) -> PostComposerViewModel {
        PostComposerViewModel(
            baby: baby,
            aiPlayName: aiPlayName,
            aiPlayId: aiPlayId,
            isSubscribed: isSubscribed,
            initialCaption: initialCaption,
            visibility: visibility,
            postService: context.postService,
            captionService: captionService
        )
    }

    @MainActor
    public static func makeFeedListViewModel(
        context: FeedIntegrationContext,
        currentBabyEnvironment: CurrentBabyEnvironment,
        mentionCandidates: [FeedMentionCandidate] = []
    ) -> FeedListViewModel {
        FeedListViewModel(
            familyId: context.familyId,
            currentUserId: context.currentUserId,
            mentionCandidates: mentionCandidates,
            feedService: context.feedService,
            engagementService: context.engagementService,
            currentBabyEnvironment: currentBabyEnvironment,
            webSocket: context.webSocket,
            accessTokenProvider: context.accessTokenProvider
        )
    }
}
