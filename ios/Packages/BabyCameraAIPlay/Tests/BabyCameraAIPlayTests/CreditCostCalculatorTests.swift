import XCTest
@testable import BabyCameraAIPlay

final class CreditCostCalculatorTests: XCTestCase {
    func testImagePlayUsesFixedCost() {
        let play = AIPlay(id: "img", name: "图", kind: .image, creditCost: 8, available: true)
        XCTAssertEqual(CreditCostCalculator.cost(for: play, durationSeconds: nil), 8)
    }

    func testVideoPlayUsesSelectedTier() {
        let play = AIPlay(
            id: "video",
            name: "视频",
            kind: .video,
            durationTiers: [
                AIPlayDurationTier(durationSeconds: 5, creditCost: 60),
                AIPlayDurationTier(durationSeconds: 10, creditCost: 120),
            ],
            available: true
        )
        XCTAssertEqual(CreditCostCalculator.cost(for: play, durationSeconds: 10), 120)
        XCTAssertEqual(CreditCostCalculator.cost(for: play, durationSeconds: nil), 60)
    }
}
