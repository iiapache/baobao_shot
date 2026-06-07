import BabyCameraNetwork
import Foundation

/// 与后端 `signin.CreditsForStreak` 对齐：连签递增 5–20 积分。
public enum SignInCredits {
    public static let minCredits = 5
    public static let maxCredits = 20
    public static let inviteRewardCredits = 50
    public static let displayLadderDays = 7

    public static func credits(forStreak streak: Int) -> Int {
        let normalized = max(streak, 1)
        return min(4 + normalized, maxCredits)
    }

    public static func nextDayCredits(afterStreak streak: Int) -> Int {
        credits(forStreak: streak + 1)
    }

    public static var ladder: [(day: Int, credits: Int)] {
        (1...displayLadderDays).map { day in
            (day, credits(forStreak: day))
        }
    }
}

public struct SignInResult: Sendable, Equatable {
    public let grantedCredits: Int
    public let balanceAfter: Int
    public let streak: Int
    public let ledgerId: String

    public init(grantedCredits: Int, balanceAfter: Int, streak: Int, ledgerId: String) {
        self.grantedCredits = grantedCredits
        self.balanceAfter = balanceAfter
        self.streak = streak
        self.ledgerId = ledgerId
    }

    init(data: CreditSignInData) {
        self.init(
            grantedCredits: data.grantedCredits,
            balanceAfter: data.balanceAfter,
            streak: data.streak,
            ledgerId: data.ledgerId
        )
    }
}
