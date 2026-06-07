import XCTest
@testable import BabyCameraNotification

@MainActor
final class UnreadBadgeStoreTests: XCTestCase {
    func testRefreshUpdatesCount() async {
        let service = MockNotificationService()
        service.unreadCount = 5
        service.listHandler = { _ in
            NotificationListData(items: [], unreadCount: 5)
        }

        let store = UnreadBadgeStore(notificationService: service)
        await store.refresh()

        XCTAssertEqual(store.unreadCount, 5)
        XCTAssertTrue(store.showsBadge)
    }

    func testClearRemovesBadge() {
        let store = UnreadBadgeStore(notificationService: MockNotificationService())
        store.syncFromServerCount(3)
        XCTAssertTrue(store.showsBadge)

        store.clear()
        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertFalse(store.showsBadge)
    }
}
