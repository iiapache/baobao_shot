import XCTest
@testable import BabyCameraWatermark

final class BrandWatermarkPolicyTests: XCTestCase {
    func testNonSubscriberAlwaysShowsBrandWatermark() {
        let policy = SubscriptionBrandWatermarkPolicy(brandWatermarkEnabled: { false })
        XCTAssertTrue(policy.shouldShowBrandWatermark(isSubscribed: false))
    }

    func testSubscriberCanDisableBrandWatermark() {
        let policy = SubscriptionBrandWatermarkPolicy(brandWatermarkEnabled: { false })
        XCTAssertFalse(policy.shouldShowBrandWatermark(isSubscribed: true))
    }

    func testSubscriberShowsBrandWatermarkWhenEnabled() {
        let policy = SubscriptionBrandWatermarkPolicy(brandWatermarkEnabled: { true })
        XCTAssertTrue(policy.shouldShowBrandWatermark(isSubscribed: true))
    }

    func testAlwaysShowPolicyIgnoresSubscription() {
        let policy = AlwaysShowBrandWatermarkPolicy()
        XCTAssertTrue(policy.shouldShowBrandWatermark(isSubscribed: false))
        XCTAssertTrue(policy.shouldShowBrandWatermark(isSubscribed: true))
    }

    func testNeverShowPolicyIgnoresSubscription() {
        let policy = NeverShowBrandWatermarkPolicy()
        XCTAssertFalse(policy.shouldShowBrandWatermark(isSubscribed: false))
        XCTAssertFalse(policy.shouldShowBrandWatermark(isSubscribed: true))
    }
}
