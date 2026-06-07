import Foundation

/// @ 提及候选家人（由宿主注入，避免 FamilyFeed 依赖 BabyCameraFamily）。
public struct FeedMentionCandidate: Sendable, Equatable, Identifiable {
    public let id: String
    public let nickname: String

    public init(id: String, nickname: String) {
        self.id = id
        self.nickname = nickname
    }
}
