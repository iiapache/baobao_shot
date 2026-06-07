import XCTest
@testable import BabyCameraNotification

final class PendingAIRefreshStoreTests: XCTestCase {
    func testUserDefaultsStoreRoundTrip() async {
        let defaults = UserDefaults(suiteName: "PendingAIRefreshStoreTests")!
        defaults.removePersistentDomain(forName: "PendingAIRefreshStoreTests")
        let store = UserDefaultsPendingAIRefreshStore(
            defaults: defaults,
            key: "pending"
        )

        let payload = RemotePushPayload(
            category: .aiDone,
            isSilent: true,
            taskId: "tsk_store",
            state: "succeeded",
            resultUrl: "https://cdn.example/store.heic"
        )
        await store.enqueue(payload)

        let dequeued = await store.dequeueAll()
        XCTAssertEqual(dequeued, [payload])

        let empty = await store.dequeueAll()
        XCTAssertTrue(empty.isEmpty)
    }
}
