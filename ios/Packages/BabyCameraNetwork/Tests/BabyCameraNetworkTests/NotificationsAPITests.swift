import XCTest
@testable import BabyCameraNetwork

final class NotificationsAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testRegisterDevice() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/notifications/devices")
            return MockResponse(statusCode: 200, json: MockServer.registerDeviceJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = NotificationsAPI(client: client)

        let result = try await api.registerDevice(
            RegisterDeviceRequest(
                deviceId: "dev_test_001",
                apnsToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab",
                appVersion: "1.0.0",
                osVersion: "iOS 17.5",
                model: "iPhone14,5"
            )
        )
        XCTAssertEqual(result.deviceId, "dev_test_001")
        XCTAssertEqual(result.region, "cn")
    }

    func testUnregisterDevice() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/v1/notifications/devices/dev_test_001")
            return MockResponse(statusCode: 200, json: MockServer.emptySuccessJSON(requestId: "req_notif_unregister"))
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = NotificationsAPI(client: client)

        try await api.unregisterDevice(deviceId: "dev_test_001")
    }

    func testListNotifications() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/notifications")
            let query = request.url?.query ?? ""
            if query.contains("cursor=page2") {
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.notificationListJSON(
                        items: [
                            NotificationItem(
                                id: "ntf_003",
                                category: .credit,
                                payload: NotificationPayload(title: "积分到账", body: "+5 积分"),
                                createdAt: "2026-06-05T10:00:00Z"
                            ),
                        ],
                        nextCursor: nil,
                        unreadCount: 0
                    )
                )
            }
            XCTAssertTrue(query.contains("limit=50"))
            return MockResponse(
                statusCode: 200,
                json: MockServer.notificationListJSON(nextCursor: "page2", unreadCount: 1)
            )
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = NotificationsAPI(client: client)

        let page1 = try await api.list()
        XCTAssertEqual(page1.items.count, 2)
        XCTAssertEqual(page1.unreadCount, 1)
        XCTAssertEqual(page1.nextCursor, "page2")

        let page2 = try await api.list(cursor: page1.nextCursor)
        XCTAssertEqual(page2.items.count, 1)
        XCTAssertEqual(page2.items[0].category, .credit)
    }

    func testMarkReadAll() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/notifications/mark-read")
            return MockResponse(statusCode: 200, json: MockServer.markNotificationsReadJSON(markedCount: 3, unreadCount: 0))
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = NotificationsAPI(client: client)

        let result = try await api.markRead()
        XCTAssertEqual(result.markedCount, 3)
        XCTAssertEqual(result.unreadCount, 0)
    }

    func testSubscriptions() async throws {
        var patchBody: [String: Any]?
        MockURLProtocol.register { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/v1/notifications/subscriptions"):
                return MockResponse(statusCode: 200, json: MockServer.notificationSubscriptionsJSON())
            case ("PATCH", "/v1/notifications/subscriptions"):
                if let data = request.httpBody {
                    patchBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                }
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.notificationSubscriptionsJSON(
                        subscriptions: [
                            NotificationSubscriptionItem(category: .milestone, enabled: true),
                            NotificationSubscriptionItem(category: .familyActivity, enabled: true),
                            NotificationSubscriptionItem(category: .aiDone, enabled: true),
                            NotificationSubscriptionItem(category: .credit, enabled: true),
                            NotificationSubscriptionItem(category: .system, enabled: true),
                        ]
                    )
                )
            default:
                return nil
            }
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = NotificationsAPI(client: client)

        let current = try await api.subscriptions()
        XCTAssertEqual(current.subscriptions.count, 5)
        XCTAssertFalse(current.subscriptions.first(where: { $0.category == .system })?.enabled ?? true)

        let updated = try await api.updateSubscriptions(
            UpdateNotificationSubscriptionsRequest(
                subscriptions: [NotificationSubscriptionItem(category: .system, enabled: true)]
            )
        )
        XCTAssertTrue(updated.subscriptions.first(where: { $0.category == .system })?.enabled ?? false)

        let subscriptions = patchBody?["subscriptions"] as? [[String: Any]]
        XCTAssertEqual(subscriptions?.count, 1)
        XCTAssertEqual(subscriptions?.first?["category"] as? String, NotificationCategoryCode.system.rawValue)
        XCTAssertEqual(subscriptions?.first?["enabled"] as? Bool, true)
    }
}
