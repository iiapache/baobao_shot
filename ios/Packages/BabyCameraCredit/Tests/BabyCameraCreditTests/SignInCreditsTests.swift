import XCTest
@testable import BabyCameraCredit

final class SignInCreditsTests: XCTestCase {
    func testCreditsForStreakMatchesBackend() {
        let cases: [(Int, Int)] = [
            (0, 5),
            (1, 5),
            (2, 6),
            (10, 14),
            (16, 20),
            (17, 20),
            (30, 20),
        ]
        for (streak, expected) in cases {
            XCTAssertEqual(SignInCredits.credits(forStreak: streak), expected, "streak \(streak)")
        }
    }

    func testLadderHasSevenDays() {
        XCTAssertEqual(SignInCredits.ladder.count, SignInCredits.displayLadderDays)
        XCTAssertEqual(SignInCredits.ladder.first?.credits, 5)
        XCTAssertEqual(SignInCredits.ladder.last?.credits, 11)
    }

    func testIAPTierNamesAlignWithPRD() {
        XCTAssertEqual(CreditIAPProductID.tierNameByProductID[CreditIAPProductID.pack60], "体验装")
        XCTAssertEqual(CreditIAPProductID.creditsByProductID[CreditIAPProductID.pack2500], 2500)
    }
}
