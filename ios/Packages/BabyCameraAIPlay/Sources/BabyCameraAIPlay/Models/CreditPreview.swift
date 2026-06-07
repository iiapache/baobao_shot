import Foundation

public struct CreditPreview: Sendable, Equatable {
    public let costCredits: Int
    public let balance: Int
    public let signInAvailable: Bool

    public init(costCredits: Int, balance: Int, signInAvailable: Bool) {
        self.costCredits = costCredits
        self.balance = balance
        self.signInAvailable = signInAvailable
    }

    public var balanceAfter: Int {
        max(balance - costCredits, 0)
    }

    public var hasSufficientCredit: Bool {
        balance >= costCredits
    }

    /// 积分不足且今日未签到时展示签到引导。
    public var shouldShowSignInHint: Bool {
        !hasSufficientCredit && signInAvailable
    }

    public var signInHint: String? {
        guard shouldShowSignInHint else { return nil }
        return "今日签到可领 5–20 积分"
    }
}

public enum CreditCostCalculator {
    public static func cost(for play: AIPlay, durationSeconds: Int?) -> Int {
        if play.kind == .video {
            if let durationSeconds,
               let tier = play.durationTiers.first(where: { $0.durationSeconds == durationSeconds }) {
                return tier.creditCost
            }
            return play.durationTiers.map(\.creditCost).min() ?? play.displayCreditCost
        }
        return play.creditCost ?? play.displayCreditCost
    }
}
