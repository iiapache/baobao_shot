import BabyCameraNetwork
import XCTest
@testable import BabyCameraNotification

@MainActor
final class NotificationCenterViewModelTests: XCTestCase {
    func testOnAppearLoadsAndMarksRead() async {
        let service = MockNotificationService()
        service.unreadCount = 2
        service.listHandler = { _ in
            NotificationListData(
                items: [
                    NotificationItem(
                        id: "ntf_1",
                        category: .familyActivity,
                        payload: NotificationPayload(title: "新点赞", body: "外婆点赞了照片"),
                        createdAt: "2026-06-06T08:00:00Z"
                    ),
                ],
                unreadCount: 2
            )
        }
        service.markReadHandler = {
            MarkNotificationsReadData(markedCount: 2, unreadCount: 0)
        }

        let badgeStore = UnreadBadgeStore(notificationService: service)
        badgeStore.syncFromServerCount(2)

        let viewModel = NotificationCenterViewModel(
            notificationService: service,
            badgeStore: badgeStore
        )

        await viewModel.onAppear()

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(service.listCallCount, 1)
        XCTAssertEqual(service.markReadCallCount, 1)
        XCTAssertEqual(badgeStore.unreadCount, 0)
        XCTAssertFalse(viewModel.hasUnread)
    }

    func testPagination() async {
        let service = MockNotificationService()
        service.listHandler = { cursor in
            if cursor == "page2" {
                return NotificationListData(
                    items: [
                        NotificationItem(
                            id: "ntf_2",
                            category: .credit,
                            payload: NotificationPayload(title: "积分到账", body: "+5"),
                            createdAt: "2026-06-05T10:00:00Z"
                        ),
                    ],
                    nextCursor: nil,
                    unreadCount: 0
                )
            }
            return NotificationListData(
                items: [
                    NotificationItem(
                        id: "ntf_1",
                        category: .familyActivity,
                        payload: NotificationPayload(title: "新发布", body: "豆豆的新照片"),
                        createdAt: "2026-06-06T08:00:00Z"
                    ),
                ],
                nextCursor: "page2",
                unreadCount: 1
            )
        }

        let viewModel = NotificationCenterViewModel(
            notificationService: service,
            badgeStore: UnreadBadgeStore(notificationService: service)
        )

        await viewModel.reload()
        await viewModel.loadMoreIfNeeded(currentItem: viewModel.items[0])

        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.items[1].category, .credit)
    }
}
