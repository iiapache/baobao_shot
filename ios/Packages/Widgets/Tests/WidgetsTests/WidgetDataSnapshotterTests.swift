import XCTest
@testable import Widgets

final class WidgetDataSnapshotterTests: XCTestCase {
    private let calendar = makeWidgetTestCalendar()
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    func testSnapshotWritesJSONAndBothThumbnailSizes() async throws {
        let container = try TempWidgetAppGroupContainer()
        let store = WidgetAppGroupStore(container: container)
        let reloader = MockWidgetTimelineReloader()
        let snapshotter = WidgetDataSnapshotter(
            store: store,
            timelineReloader: reloader,
            calendar: calendar,
            clock: MockWidgetClock(fixedDate: fixedNow)
        )

        let imageDirectory = try container.containerURL().appendingPathComponent("sources", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)

        let photoURL = imageDirectory.appendingPathComponent("photo_1.jpg")
        try WidgetTestImageFactory.writeJPEGFile(width: 1800, height: 1200, to: photoURL)

        let avatarURL = imageDirectory.appendingPathComponent("avatar.jpg")
        try WidgetTestImageFactory.writeJPEGFile(width: 800, height: 800, to: avatarURL, color: (0.2, 0.5, 0.9))

        let referenceDate = makeWidgetTestDate(year: 2024, month: 6, day: 7, calendar: calendar)
        let request = WidgetSnapshotRequest(
            baby: WidgetSnapshotBabyInfo(
                id: "baby_1",
                name: "豆豆",
                birthDate: "2024-01-01",
                avatarSourceURL: avatarURL
            ),
            photos: [
                WidgetSnapshotPhotoCandidate(
                    photoId: "photo_1",
                    takenAt: makeWidgetTestDate(year: 2024, month: 6, day: 7, hour: 18, calendar: calendar),
                    sourceImageURL: photoURL
                ),
            ],
            referenceDate: referenceDate
        )

        let snapshot = try await snapshotter.snapshot(request)

        XCTAssertEqual(snapshot.babyId, "baby_1")
        XCTAssertEqual(snapshot.babyName, "豆豆")
        XCTAssertEqual(snapshot.growthDays, 159)
        XCTAssertEqual(snapshot.updatedAt, fixedNow)
        XCTAssertEqual(snapshot.recentDays.count, 1)
        XCTAssertEqual(snapshot.recentDays.first?.photoId, "photo_1")
        XCTAssertEqual(snapshot.avatarThumbnailSmall, "thumbnails/avatar_baby_1_200.jpg")
        XCTAssertEqual(snapshot.avatarThumbnailLarge, "thumbnails/avatar_baby_1_600.jpg")
        XCTAssertEqual(reloader.reloadCount, 1)

        let loaded = try XCTUnwrap(try store.readSnapshot())
        XCTAssertEqual(loaded, snapshot)

        let smallPhoto = try container.containerURL().appendingPathComponent("thumbnails/photo_1_200.jpg")
        let largePhoto = try container.containerURL().appendingPathComponent("thumbnails/photo_1_600.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: smallPhoto.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: largePhoto.path))
        XCTAssertGreaterThan(try Data(contentsOf: smallPhoto).count, 0)
        XCTAssertGreaterThan(try Data(contentsOf: largePhoto).count, 0)
    }

    func testSnapshotUsesMockStoreWithoutTouchingLiveAppGroup() async throws {
        let store = MockWidgetSnapshotStore()
        let reloader = MockWidgetTimelineReloader()
        let snapshotter = WidgetDataSnapshotter(
            store: store,
            timelineReloader: reloader,
            calendar: calendar,
            clock: MockWidgetClock(fixedDate: fixedNow)
        )

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-snapshotter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let photoURL = tempDirectory.appendingPathComponent("photo.jpg")
        try WidgetTestImageFactory.writeJPEGFile(width: 1200, height: 900, to: photoURL)

        let request = WidgetSnapshotRequest(
            baby: WidgetSnapshotBabyInfo(id: "baby_2", name: "糖糖", birthDate: "2024-03-01"),
            photos: [
                WidgetSnapshotPhotoCandidate(
                    photoId: "photo_9",
                    takenAt: makeWidgetTestDate(year: 2024, month: 6, day: 2, calendar: calendar),
                    sourceImageURL: photoURL
                ),
            ],
            referenceDate: makeWidgetTestDate(year: 2024, month: 6, day: 2, calendar: calendar)
        )

        _ = try await snapshotter.snapshot(request)

        XCTAssertEqual(store.thumbnails.keys.sorted(), [
            "thumbnails/photo_9_200.jpg",
            "thumbnails/photo_9_600.jpg",
        ])
        XCTAssertEqual(store.snapshot?.growthDays, 94)
        XCTAssertEqual(reloader.reloadCount, 1)
    }

    func testSnapshotThrowsWhenSourceImageMissing() async {
        let store = MockWidgetSnapshotStore()
        let snapshotter = WidgetDataSnapshotter(store: store, calendar: calendar)

        let request = WidgetSnapshotRequest(
            baby: WidgetSnapshotBabyInfo(id: "baby_3", name: "测试", birthDate: "2024-01-01"),
            photos: [
                WidgetSnapshotPhotoCandidate(
                    photoId: "missing",
                    takenAt: makeWidgetTestDate(year: 2024, month: 6, day: 1, calendar: calendar),
                    sourceImageURL: URL(fileURLWithPath: "/tmp/does-not-exist.jpg")
                ),
            ],
            referenceDate: makeWidgetTestDate(year: 2024, month: 6, day: 1, calendar: calendar)
        )

        do {
            _ = try await snapshotter.snapshot(request)
            XCTFail("Expected source image error")
        } catch let error as WidgetError {
            XCTAssertEqual(error, .sourceImageUnreadable(URL(fileURLWithPath: "/tmp/does-not-exist.jpg")))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
