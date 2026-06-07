import BabyCameraNetwork
import Foundation

public protocol EngagementServing: Sendable {
    func loadEngagement(postId: String, currentUserId: String) async throws -> FeedEngagementState
    func toggleLike(
        postId: String,
        currentUserId: String,
        currentlyLiked: Bool
    ) async throws -> FeedEngagementState
    func createComment(
        postId: String,
        currentUserId: String,
        text: String,
        mentions: [FeedMentionCandidate]
    ) async throws -> FeedEngagementState
    func applyRemoteEvent(
        _ event: FeedEngagementRemoteEvent,
        currentUserId: String,
        isViewingPost: Bool
    ) async throws
    func engagementState(for postId: String) async -> FeedEngagementState
    func flushOfflineQueue(currentUserId: String) async throws
    func offlinePendingCount() async -> Int
}
