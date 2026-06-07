import BabyCameraNetwork
import XCTest
@testable import BabyCameraNotification

final class NotificationServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testMarkAllReadClearsUnreadCount() async throws {
        MockURLProtocol.register { request in
            switch request.url?.path {
            case "/v1/notifications/mark-read":
                return MockResponse(statusCode: 200, json: MockServer.markNotificationsReadJSON(markedCount: 2, unreadCount: 0))
            default:
                return nil
            }
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))

        let service = NotificationService(
            configuration: NotificationServiceConfiguration(
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            ),
            clientFactory: { store in
                makeAuthenticatedClient(tokenStore: store, session: MockURLProtocol.makeSession())
            }
        )

        let result = try await service.markAllRead()
        XCTAssertEqual(result.unreadCount, 0)
        XCTAssertEqual(service.unreadCount, 0)
    }

    func testUpdateLockedCategoryThrows() async throws {
        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))

        let service = NotificationService(
            configuration: NotificationServiceConfiguration(tokenStore: tokenStore)
        )

        do {
            _ = try await service.updateCategory(.aiDone, enabled: false)
            XCTFail("expected categoryLocked")
        } catch let error as NotificationServiceError {
            XCTAssertEqual(error, .categoryLocked(.aiDone))
        }
    }

    func testLoadAndUpdateCategorySubscriptions() async throws {
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
        let service = NotificationService(
            configuration: NotificationServiceConfiguration(
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            ),
            clientFactory: { store in
                makeAuthenticatedClient(tokenStore: store, session: MockURLProtocol.makeSession())
            }
        )

        let loaded = try await service.loadCategorySubscriptions()
        XCTAssertFalse(loaded.first(where: { $0.code == .system })?.enabled ?? true)

        let updated = try await service.updateCategory(.system, enabled: true)
        XCTAssertTrue(updated.first(where: { $0.code == .system })?.enabled ?? false)

        let subscriptions = patchBody?["subscriptions"] as? [[String: Any]]
        XCTAssertEqual(subscriptions?.first?["category"] as? String, NotificationCategoryCode.system.rawValue)
        XCTAssertEqual(subscriptions?.first?["enabled"] as? Bool, true)
    }
}
