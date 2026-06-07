import XCTest
@testable import Widgets

final class WidgetAppGroupStoreTests: XCTestCase {
    func testWriteAndReadSnapshotRoundTrip() throws {
        let container = try TempWidgetAppGroupContainer()
        let store = WidgetAppGroupStore(container: container)

        let snapshot = WidgetSnapshot(
            babyId: "baby_1",
            babyName: "豆豆",
            growthDays: 120,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            avatarThumbnailSmall: "thumbnails/avatar_baby_1_200.jpg",
            avatarThumbnailLarge: "thumbnails/avatar_baby_1_600.jpg",
            recentDays: [
                WidgetSnapshotDayEntry(
                    date: "2024-06-01",
                    photoId: "photo_1",
                    thumbnailSmall: "thumbnails/photo_1_200.jpg",
                    thumbnailLarge: "thumbnails/photo_1_600.jpg"
                ),
            ]
        )

        try store.writeSnapshot(snapshot)
        let loaded = try XCTUnwrap(try store.readSnapshot())

        XCTAssertEqual(loaded, snapshot)
    }

    func testWriteThumbnailCreatesFileUnderContainer() throws {
        let container = try TempWidgetAppGroupContainer()
        let store = WidgetAppGroupStore(container: container)
        let payload = Data([0x01, 0x02, 0x03])

        let relativePath = try store.writeThumbnail(payload, photoId: "photo_42", size: .small)
        XCTAssertEqual(relativePath, "thumbnails/photo_42_200.jpg")

        let fileURL = try container.containerURL().appendingPathComponent(relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(try Data(contentsOf: fileURL), payload)
    }
}
