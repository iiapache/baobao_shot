import XCTest
@testable import Widgets

final class BabyWidgetKindTests: XCTestCase {
    func testAllKindsAreUnique() {
        let identifiers = BabyWidgetKind.allCases.map(\.identifier)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertEqual(identifiers.count, 4)
    }

    func testKindIdentifiersMatchDesign() {
        XCTAssertEqual(BabyWidgetKind.small.identifier, "BabyCameraWidgetSmall")
        XCTAssertEqual(BabyWidgetKind.medium.identifier, "BabyCameraWidgetMedium")
        XCTAssertEqual(BabyWidgetKind.large.identifier, "BabyCameraWidgetLarge")
        XCTAssertEqual(BabyWidgetKind.lockScreen.identifier, "BabyCameraWidgetLockScreen")
    }
}
