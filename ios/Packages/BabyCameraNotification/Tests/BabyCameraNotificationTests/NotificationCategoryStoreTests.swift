import BabyCameraNetwork
import XCTest
@testable import BabyCameraNotification

@MainActor
final class NotificationCategoryStoreTests: XCTestCase {
    func testDefaultCategoriesMatchPRD() {
        let defaults = NotificationCategory.allDefaults
        XCTAssertEqual(defaults.first(where: { $0.code == .milestone })?.enabled, true)
        XCTAssertEqual(defaults.first(where: { $0.code == .familyActivity })?.enabled, true)
        XCTAssertEqual(defaults.first(where: { $0.code == .aiDone })?.enabled, true)
        XCTAssertEqual(defaults.first(where: { $0.code == .credit })?.enabled, true)
        XCTAssertEqual(defaults.first(where: { $0.code == .system })?.enabled, false)
        XCTAssertFalse(NotificationCategory.userCanDisable(.aiDone))
    }

    func testLoadSubscriptions() async {
        let service = MockNotificationService()
        service.subscriptionsHandler = {
            NotificationCategory.merge(
                remote: [
                    NotificationSubscriptionItem(category: .system, enabled: true),
                ]
            )
        }

        let store = NotificationCategoryStore(notificationService: service)
        await store.load()

        XCTAssertTrue(store.isEnabled(.system))
        XCTAssertNil(store.errorMessage)
    }

    func testCannotDisableAIDone() async {
        let service = MockNotificationService()
        service.updateHandler = { _, _ in
            throw NotificationServiceError.categoryLocked(.aiDone)
        }

        let store = NotificationCategoryStore(notificationService: service)
        await store.setEnabled(false, for: .aiDone)

        XCTAssertNotNil(store.lockedCategoryHint)
        XCTAssertTrue(store.lockedCategoryHint?.contains("AI 任务完成") ?? false)
    }

    func testUpdateCategorySuccess() async {
        let service = MockNotificationService()
        service.updateHandler = { category, enabled in
            var categories = NotificationCategory.allDefaults
            if let index = categories.firstIndex(where: { $0.code == category }) {
                categories[index].enabled = enabled
            }
            return categories
        }

        let store = NotificationCategoryStore(notificationService: service)
        await store.setEnabled(true, for: .system)

        XCTAssertTrue(store.isEnabled(.system))
        XCTAssertNil(store.lockedCategoryHint)
    }
}
