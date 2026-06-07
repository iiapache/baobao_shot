import XCTest
@testable import Widgets

final class WidgetAppGroupConfigurationTests: XCTestCase {
    func testAppGroupIdentifierMatchesDesignSpec() {
        XCTAssertEqual(WidgetAppGroupConfiguration.groupIdentifier, "group.app.babycamera")
    }

    func testSnapshotFileName() {
        XCTAssertEqual(WidgetAppGroupConfiguration.snapshotFileName, "widget_snapshot.json")
    }
}
