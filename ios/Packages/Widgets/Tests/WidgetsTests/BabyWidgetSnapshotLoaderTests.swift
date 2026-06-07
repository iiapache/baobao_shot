import XCTest
@testable import Widgets

final class BabyWidgetSnapshotLoaderTests: XCTestCase {
    func testLoadSnapshotDelegatesToStore() throws {
        let store = MockWidgetSnapshotStore()
        let snapshot = WidgetSnapshot(
            babyId: "baby_loader",
            babyName: "测试",
            growthDays: 30,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            recentDays: []
        )
        try store.writeSnapshot(snapshot)

        let loader = BabyWidgetSnapshotLoader(store: store)
        let loaded = try XCTUnwrap(try loader.loadSnapshot())

        XCTAssertEqual(loaded, snapshot)
    }

    func testLoadSnapshotReturnsNilWhenMissing() throws {
        let loader = BabyWidgetSnapshotLoader(store: MockWidgetSnapshotStore())
        XCTAssertNil(try loader.loadSnapshot())
    }
}
