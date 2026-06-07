import BabyCameraBaby
import BabyCameraNetwork
import Foundation

@MainActor
public final class FeedListViewModel: ObservableObject {
    @Published public private(set) var posts: [FeedPost] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingMore = false
    @Published public private(set) var isOffline = false
    @Published public private(set) var engagementByPostId: [String: FeedEngagementState] = [:]
    @Published public private(set) var totalUnreadCount = 0
    @Published public private(set) var showLikeAnimationPostId: String?
    @Published public var errorMessage: String?
    @Published public var commentComposerPostId: String?
    @Published public var commentDraft = ""

    public let familyId: String
    public let currentUserId: String
    public let mentionCandidates: [FeedMentionCandidate]
    public let feedService: any FeedServing
    public let engagementService: any EngagementServing
    public let currentBabyEnvironment: CurrentBabyEnvironment

    private let webSocket: (any FeedWebSocketConnecting)?
    private let accessTokenProvider: (@Sendable () async -> String?)?
    private var nextCursor: String?
    private var hasLoadedCache = false
    private var webSocketTasks: [Task<Void, Never>] = []
    private var viewedPostIds: Set<String> = []

    public init(
        familyId: String,
        currentUserId: String,
        mentionCandidates: [FeedMentionCandidate] = [],
        feedService: any FeedServing,
        engagementService: any EngagementServing,
        currentBabyEnvironment: CurrentBabyEnvironment,
        webSocket: (any FeedWebSocketConnecting)? = nil,
        accessTokenProvider: (@Sendable () async -> String?)? = nil
    ) {
        self.familyId = familyId
        self.currentUserId = currentUserId
        self.mentionCandidates = mentionCandidates
        self.feedService = feedService
        self.engagementService = engagementService
        self.currentBabyEnvironment = currentBabyEnvironment
        self.webSocket = webSocket
        self.accessTokenProvider = accessTokenProvider
    }

    public var currentBabyId: String? {
        currentBabyEnvironment.currentBabyId
    }

    public func onAppear() async {
        startWebSocketIfNeeded()
        await reload()
        await syncOfflineEngagement()
    }

    public func onDisappear() {
        webSocketTasks.forEach { $0.cancel() }
        webSocketTasks.removeAll()
        webSocket?.disconnect()
    }

    public func reload() async {
        isLoading = true
        errorMessage = nil
        nextCursor = nil
        defer { isLoading = false }

        let babyId = currentBabyId

        if !hasLoadedCache {
            do {
                let cached = try await feedService.cachedPage(familyId: familyId, babyId: babyId)
                posts = cached.items
                hasLoadedCache = true
                await loadEngagementForVisiblePosts()
            } catch {
                // 缓存读取失败不阻塞网络拉取。
            }
        }

        do {
            let page = try await feedService.fetchPage(
                familyId: familyId,
                babyId: babyId,
                cursor: nil,
                persistToCache: true
            )
            posts = page.items
            nextCursor = page.nextCursor
            isOffline = false
            await loadEngagementForVisiblePosts()
            await syncOfflineEngagement()
        } catch {
            isOffline = true
            if posts.isEmpty {
                errorMessage = mapError(error)
            }
        }
        await refreshUnreadCount()
    }

    public func loadMoreIfNeeded(currentPost: FeedPost) async {
        guard let nextCursor, !nextCursor.isEmpty, !isLoadingMore else { return }
        guard posts.last?.id == currentPost.id else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await feedService.fetchPage(
                familyId: familyId,
                babyId: currentBabyId,
                cursor: nextCursor,
                persistToCache: false
            )
            posts.append(contentsOf: page.items)
            self.nextCursor = page.nextCursor
            isOffline = false
            await loadEngagementForVisiblePosts()
        } catch {
            errorMessage = mapError(error)
        }
    }

    public func applyBabyFilter() async {
        await reload()
    }

    /// 本地乐观移除（撤回成功后、网络刷新前）。
    public func removePostLocally(postId: String) {
        posts.removeAll { $0.postId == postId }
        engagementByPostId.removeValue(forKey: postId)
        viewedPostIds.remove(postId)
        if commentComposerPostId == postId {
            commentComposerPostId = nil
            commentDraft = ""
        }
        Task { await refreshUnreadCount() }
    }

    public func displayCaption(for post: FeedPost) -> String {
        let trimmed = post.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "无文案" : trimmed
    }

    public func engagement(for postId: String) -> FeedEngagementState {
        engagementByPostId[postId] ?? .empty
    }

    public func doubleTapLike(post: FeedPost) async {
        let current = engagement(for: post.postId)
        do {
            let updated = try await engagementService.toggleLike(
                postId: post.postId,
                currentUserId: currentUserId,
                currentlyLiked: current.likedByCurrentUser
            )
            engagementByPostId[post.postId] = updated
            if !current.likedByCurrentUser {
                showLikeAnimationPostId = post.postId
                try? await Task.sleep(nanoseconds: 600_000_000)
                if showLikeAnimationPostId == post.postId {
                    showLikeAnimationPostId = nil
                }
            }
            await refreshUnreadCount()
        } catch {
            let updated = await engagementService.engagementState(for: post.postId)
            engagementByPostId[post.postId] = updated
            if isOffline {
                errorMessage = "已离线保存，联网后自动同步"
            } else {
                errorMessage = mapError(error)
            }
        }
    }

    public func beginComment(on post: FeedPost) {
        commentComposerPostId = post.postId
        commentDraft = ""
        viewedPostIds.insert(post.postId)
        markEngagementRead(postId: post.postId)
    }

    public func insertMention(_ candidate: FeedMentionCandidate) {
        commentDraft = MentionResolver.insertMention(candidate, into: commentDraft)
    }

    public func submitComment() async {
        guard let postId = commentComposerPostId else { return }
        do {
            let updated = try await engagementService.createComment(
                postId: postId,
                currentUserId: currentUserId,
                text: commentDraft,
                mentions: mentionCandidates
            )
            engagementByPostId[postId] = updated
            commentComposerPostId = nil
            commentDraft = ""
            await refreshUnreadCount()
        } catch {
            if isOffline {
                errorMessage = "评论已离线保存，联网后自动同步"
            } else if let engagementError = error as? EngagementServiceError,
                      engagementError == .emptyComment {
                errorMessage = "评论不能为空"
            } else {
                errorMessage = mapError(error)
            }
        }
    }

    public func cancelComment() {
        commentComposerPostId = nil
        commentDraft = ""
    }

    public func markEngagementRead(postId: String) {
        viewedPostIds.insert(postId)
        if var state = engagementByPostId[postId] {
            state = FeedEngagementEventReducer.markRead(state)
            engagementByPostId[postId] = state
        }
        Task { await refreshUnreadCount() }
    }

    private func loadEngagementForVisiblePosts() async {
        for post in posts {
            if engagementByPostId[post.postId] != nil { continue }
            if let state = try? await engagementService.loadEngagement(
                postId: post.postId,
                currentUserId: currentUserId
            ) {
                engagementByPostId[post.postId] = state
            }
        }
        await refreshUnreadCount()
    }

    private func syncOfflineEngagement() async {
        do {
            try await engagementService.flushOfflineQueue(currentUserId: currentUserId)
            await loadEngagementForVisiblePosts()
        } catch {
            // 离线同步失败保留队列，等待下次重试。
        }
    }

    private func refreshUnreadCount() async {
        totalUnreadCount = engagementByPostId.values.reduce(0) { $0 + $1.unreadCount }
    }

    private func startWebSocketIfNeeded() {
        guard let webSocket, let accessTokenProvider else { return }

        webSocketTasks.forEach { $0.cancel() }
        webSocketTasks.removeAll()

        webSocketTasks.append(Task { [weak self] in
            guard let self else { return }
            if let token = await accessTokenProvider() {
                webSocket.connect(accessToken: token)
                try? await webSocket.subscribe(familyIds: [familyId])
            }
        })

        webSocketTasks.append(Task { [weak self] in
            guard let self else { return }
            for await event in webSocket.events {
                await self.handleRemoteEvent(event)
            }
        })

        webSocketTasks.append(Task { [weak self] in
            guard let self else { return }
            for await state in webSocket.connectionStates {
                if state == .connected {
                    await self.syncOfflineEngagement()
                }
            }
        })
    }

    private func handleRemoteEvent(_ event: FeedEngagementRemoteEvent) async {
        let postId: String
        switch event {
        case let .likeAdded(_, id, _, _),
             let .likeRemoved(_, id, _),
             let .commentAdded(_, id, _, _, _, _),
             let .commentRemoved(_, id, _, _):
            postId = id
        }

        let isViewing = viewedPostIds.contains(postId) || commentComposerPostId == postId
        try? await engagementService.applyRemoteEvent(
            event,
            currentUserId: currentUserId,
            isViewingPost: isViewing
        )
        let state = await engagementService.engagementState(for: postId)
        engagementByPostId[postId] = state
        await refreshUnreadCount()
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }
}
