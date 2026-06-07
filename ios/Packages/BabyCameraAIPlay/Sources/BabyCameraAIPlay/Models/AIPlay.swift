import Foundation

public struct AIPlayDurationTier: Sendable, Equatable, Identifiable {
    public let durationSeconds: Int
    public let creditCost: Int

    public var id: Int { durationSeconds }

    public init(durationSeconds: Int, creditCost: Int) {
        self.durationSeconds = durationSeconds
        self.creditCost = creditCost
    }
}

public struct AIPlay: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let kind: AIPlayKind
    public let creditCost: Int?
    public let durationTiers: [AIPlayDurationTier]
    public let available: Bool

    public init(
        id: String,
        name: String,
        description: String? = nil,
        kind: AIPlayKind,
        creditCost: Int? = nil,
        durationTiers: [AIPlayDurationTier] = [],
        available: Bool
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.kind = kind
        self.creditCost = creditCost
        self.durationTiers = durationTiers
        self.available = available
    }

    /// 展示用积分：视频取最低档位，图像取固定值，免费玩法为 0。
    public var displayCreditCost: Int {
        if let creditCost, creditCost > 0 {
            return creditCost
        }
        if let minTier = durationTiers.map(\.creditCost).min() {
            return minTier
        }
        return 0
    }

    public var creditLabel: String {
        let cost = displayCreditCost
        if cost == 0 {
            return "免费"
        }
        return "\(cost) 积分"
    }
}

public struct PlaysCatalog: Sendable, Equatable {
    public let version: String
    public let region: AppRegion
    public let ttlSeconds: TimeInterval
    public let plays: [AIPlay]

    public init(
        version: String,
        region: AppRegion,
        ttlSeconds: TimeInterval,
        plays: [AIPlay]
    ) {
        self.version = version
        self.region = region
        self.ttlSeconds = ttlSeconds
        self.plays = plays
    }

    /// 当前区域可用玩法（服务端已按区域白名单过滤，端侧再排除 `available == false`）。
    public var availablePlays: [AIPlay] {
        plays.filter(\.available)
    }
}
