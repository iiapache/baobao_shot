import BabyCameraNetwork
import XCTest
@testable import BabyCameraNotification

final class NotificationCategoryTests: XCTestCase {
    func testMergeKeepsAIDoneEnabledWhenRemoteDisabled() {
        let merged = NotificationCategory.merge(
            remote: [
                NotificationSubscriptionItem(category: .aiDone, enabled: false),
                NotificationSubscriptionItem(category: .system, enabled: true),
            ]
        )

        XCTAssertTrue(merged.first(where: { $0.code == .aiDone })?.enabled ?? false)
        XCTAssertTrue(merged.first(where: { $0.code == .system })?.enabled ?? false)
    }

    func testAllCategoryCodesCovered() {
        XCTAssertEqual(NotificationCategoryCode.allCases.count, 5)
        XCTAssertEqual(NotificationCategory.allDefaults.count, 5)
    }
}
