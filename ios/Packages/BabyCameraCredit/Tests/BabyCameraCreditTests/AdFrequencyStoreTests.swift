import XCTest
@testable import BabyCameraCredit

final class AdFrequencyStoreTests: XCTestCase {
    private let day = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 6))!

    func testSplashLimitOnePerDay() {
        let store = InMemoryAdFrequencyStore()
        let gate = AdFrequencyGate(store: store, limits: .default, now: { self.day })

        XCTAssertTrue(gate.canShow(.splash))
        gate.recordShown(.splash)
        XCTAssertFalse(gate.canShow(.splash))
        XCTAssertTrue(gate.canShow(.interstitial))
    }

    func testInterstitialLimitThreePerDay() {
        let store = InMemoryAdFrequencyStore()
        let gate = AdFrequencyGate(store: store, limits: .default, now: { self.day })

        for _ in 0..<3 {
            XCTAssertTrue(gate.canShow(.interstitial))
            gate.recordShown(.interstitial)
        }
        XCTAssertFalse(gate.canShow(.interstitial))
    }

    func testRewardedHasNoClientFrequencyLimit() {
        let store = InMemoryAdFrequencyStore()
        let gate = AdFrequencyGate(store: store, limits: .default, now: { self.day })

        for _ in 0..<10 {
            XCTAssertTrue(gate.canShow(.rewarded))
            gate.recordShown(.rewarded)
        }
    }
}
