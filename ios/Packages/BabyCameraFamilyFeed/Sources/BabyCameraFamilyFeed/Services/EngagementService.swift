import BabyCameraNetwork
import Database
import Foundation

public enum EngagementServiceError: Error, Equatable, Sendable {
    case emptyComment
    case networkUnavailable
}

/// 点赞 / 评论服务：本地缓存 + 离线队列 + WS 增量合并。
public actor EngagementService: EngagementServing {
    private let engagementAPI: EngagementAPI
    private let cacheRepository: any FeedCacheRepository
    private let offlineQueue: EngagementOfflineQueue
    private var states: [String: FeedEngagementState] = [:]

    public init(
        engagementAPI: EngagementAPI,
        cacheRepository: any FeedCacheRepository,
        offlineQueue: EngagementOfflineQueue
    ) {
        self.engagementAPI = engagementAPI
        self.cacheRepository = cacheRepository
        self.offlineQueue = offlineQueue
    }

    public func loadEngagement(postId: String, currentUserId: String) async throws -> FeedEngagementState {
        if let cached = states[postId] {
            return cached
        }

        let likes = try await cacheRepository.fetchLikes(postId: postId)
        let comments = try await cacheRepository.fetchComments(postId: postId)
        let mappedComments = comments.map { record in
            FeedComment(
                commentId: record.id,
                postId: record.postId,
                userId: record.userId,
                text: record.text,
                createdAt: FeedPostCacheMapper.isoString(fromUnix: record.createdAt)
            )
        }

        let state = FeedEngagementState(
            likeCount: likes.count,
            commentCount: mappedComments.count,
            likedByCurrentUser: likes.contains { $0.userId == currentUserId },
            unreadCount: 0,
            comments: mappedComments
        )
        states[postId] = state
        return state
    }

    public func toggleLike(
        postId: String,
        currentUserId: String,
        currentlyLiked: Bool
    ) async throws -> FeedEngagementState {
        var state = try await loadEngagement(postId: postId, currentUserId: currentUserId)

        if currentlyLiked {
            state = FeedEngagementEventReducer.apply(
                event: .likeRemoved(familyId: "", postId: postId, userId: currentUserId),
                to: state,
                currentUserId: currentUserId,
                isViewingPost: true
            )
            states[postId] = state

            do {
                _ = try await engagementAPI.unlike(postId: postId)
                try await cacheRepository.deleteLike(postId: postId, userId: currentUserId)
            } catch {
                try await offlineQueue.enqueue(.unlike(postId: postId))
                throw error
            }
        } else {
            let likedAt = ISO8601DateFormatter().string(from: Date())
            state = FeedEngagementEventReducer.apply(
                event: .likeAdded(
                    familyId: "",
                    postId: postId,
                    userId: currentUserId,
                    likedAt: likedAt
                ),
                to: state,
                currentUserId: currentUserId,
                isViewingPost: true
            )
            states[postId] = state

            do {
                let response = try await engagementAPI.like(postId: postId)
                try await cacheRepository.saveLike(
                    LikeCacheRecord(
                        postId: postId,
                        userId: currentUserId,
                        likedAt: FeedPostCacheMapper.unixTime(fromISO: response.likedAt)
                    )
                )
            } catch {
                try await offlineQueue.enqueue(.like(postId: postId))
                throw error
            }
        }

        return state
    }

    public func createComment(
        postId: String,
        currentUserId: String,
        text: String,
        mentions: [FeedMentionCandidate]
    ) async throws -> FeedEngagementState {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EngagementServiceError.emptyComment
        }

        let mentionUserIds = MentionResolver.mentionUserIds(in: trimmed, candidates: mentions)
        return try await submitComment(
            postId: postId,
            currentUserId: currentUserId,
            text: trimmed,
            mentionUserIds: mentionUserIds
        )
    }

    private func submitComment(
        postId: String,
        currentUserId: String,
        text: String,
        mentionUserIds: [String]
    ) async throws -> FeedEngagementState {
        var state = try await loadEngagement(postId: postId, currentUserId: currentUserId)

        do {
            let response = try await engagementAPI.createComment(
                postId: postId,
                request: CreateCommentRequest(
                    text: text,
                    mentionUserIds: mentionUserIds.isEmpty ? nil : mentionUserIds
                )
            )
            let comment = FeedComment(
                commentId: response.commentId,
                postId: response.postId,
                userId: response.userId,
                text: response.text,
                createdAt: response.createdAt
            )
            state = FeedEngagementEventReducer.apply(
                event: .commentAdded(
                    familyId: "",
                    postId: postId,
                    userId: currentUserId,
                    commentId: comment.commentId,
                    text: comment.text,
                    createdAt: comment.createdAt
                ),
                to: state,
                currentUserId: currentUserId,
                isViewingPost: true
            )
            states[postId] = state
            try await cacheRepository.saveComment(
                CommentCacheRecord(
                    id: comment.commentId,
                    postId: comment.postId,
                    userId: comment.userId,
                    text: comment.text,
                    createdAt: FeedPostCacheMapper.unixTime(fromISO: comment.createdAt)
                )
            )
            return state
        } catch {
            try await offlineQueue.enqueue(
                .comment(postId: postId, text: text, mentionUserIds: mentionUserIds)
            )
            throw error
        }
    }

    public func applyRemoteEvent(
        _ event: FeedEngagementRemoteEvent,
        currentUserId: String,
        isViewingPost: Bool
    ) async throws {
        switch event {
        case let .likeAdded(_, id, userId, likedAt):
            var state = states[id] ?? .empty
            state = FeedEngagementEventReducer.apply(
                event: event,
                to: state,
                currentUserId: currentUserId,
                isViewingPost: isViewingPost
            )
            states[id] = state
            if userId != currentUserId {
                try await cacheRepository.saveLike(
                    LikeCacheRecord(
                        postId: id,
                        userId: userId,
                        likedAt: FeedPostCacheMapper.unixTime(fromISO: likedAt)
                    )
                )
            }

        case let .likeRemoved(_, id, userId):
            var state = states[id] ?? .empty
            state = FeedEngagementEventReducer.apply(
                event: event,
                to: state,
                currentUserId: currentUserId,
                isViewingPost: isViewingPost
            )
            states[id] = state
            try await cacheRepository.deleteLike(postId: id, userId: userId)

        case let .commentAdded(_, id, userId, commentId, text, createdAt):
            var state = states[id] ?? .empty
            state = FeedEngagementEventReducer.apply(
                event: event,
                to: state,
                currentUserId: currentUserId,
                isViewingPost: isViewingPost
            )
            states[id] = state
            try await cacheRepository.saveComment(
                CommentCacheRecord(
                    id: commentId,
                    postId: id,
                    userId: userId,
                    text: text,
                    createdAt: FeedPostCacheMapper.unixTime(fromISO: createdAt)
                )
            )

        case let .commentRemoved(_, id, _, _):
            var state = states[id] ?? .empty
            state = FeedEngagementEventReducer.apply(
                event: event,
                to: state,
                currentUserId: currentUserId,
                isViewingPost: isViewingPost
            )
            states[id] = state
        }
    }

    public func engagementState(for postId: String) async -> FeedEngagementState {
        states[postId] ?? .empty
    }

    public func markRead(postId: String) async {
        guard var state = states[postId] else { return }
        state = FeedEngagementEventReducer.markRead(state)
        states[postId] = state
    }

    public func flushOfflineQueue(currentUserId: String) async throws {
        let pending = try await offlineQueue.snapshot()
        guard !pending.isEmpty else { return }

        var remaining: [PendingEngagementAction] = []
        for action in pending {
            do {
                switch action {
                case let .like(postId):
                    _ = try await toggleLike(
                        postId: postId,
                        currentUserId: currentUserId,
                        currentlyLiked: false
                    )
                case let .unlike(postId):
                    _ = try await toggleLike(
                        postId: postId,
                        currentUserId: currentUserId,
                        currentlyLiked: true
                    )
                case let .comment(postId, text, mentionUserIds):
                    _ = try await submitComment(
                        postId: postId,
                        currentUserId: currentUserId,
                        text: text,
                        mentionUserIds: mentionUserIds
                    )
                }
            } catch {
                remaining.append(action)
            }
        }
        try await offlineQueue.replaceAll(remaining)
    }

    public func offlinePendingCount() async -> Int {
        (try? await offlineQueue.snapshot().count) ?? 0
    }
}
