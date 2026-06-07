import Foundation

/// 提交前积分预扣预览（T4.16）。
public struct CreditCostPreview: Sendable, Equatable {
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
}
