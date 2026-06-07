import XCTest
@testable import BabyCameraFamily

final class ProductLimitsTests: XCTestCase {
    func testLimitsMatchProductConfigBaseline() {
        XCTAssertEqual(ProductLimits.maxFamilyMembers, 8)
        XCTAssertEqual(ProductLimits.maxBabiesPerFamily, 5)
        XCTAssertEqual(ProductLimits.inviteCodeLength, 6)
        XCTAssertEqual(ProductLimits.inviteTTLHours, 24)
        XCTAssertEqual(ProductLimits.inviteMaxUses, 8)
    }
}
