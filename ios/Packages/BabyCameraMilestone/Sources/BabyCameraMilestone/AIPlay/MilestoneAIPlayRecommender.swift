import Foundation

/// 里程碑当日进入相机时置顶推荐的 AI 玩法（P3 联调前为 stub）。
public protocol MilestoneAIPlayRecommending: Sendable {
    func recommendedPlayIDs(babyId: String, milestoneDate: Date) async -> [String]
}

/// 占位实现：返回空列表，待 P3 `PlayCatalogService` 联调后替换。
public struct StubMilestoneAIPlayRecommender: MilestoneAIPlayRecommending {
    public init() {}

    public func recommendedPlayIDs(babyId: String, milestoneDate: Date) async -> [String] {
        _ = babyId
        _ = milestoneDate
        return []
    }
}
