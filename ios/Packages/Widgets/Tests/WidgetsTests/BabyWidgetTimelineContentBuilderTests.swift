import XCTest
@testable import Widgets

final class BabyWidgetTimelineContentBuilderTests: XCTestCase {
    private let calendar = makeWidgetTestCalendar()

    func testPlaceholderUsesPreviewDefaults() {
        let referenceDate = makeWidgetTestDate(year: 2024, month: 6, day: 7, calendar: calendar)
        let content = BabyWidgetTimelineContentBuilder.placeholder(referenceDate: referenceDate)

        XCTAssertTrue(content.isPlaceholder)
        XCTAssertEqual(content.babyName, BabyWidgetTimelineContentBuilder.placeholderBabyName)
        XCTAssertEqual(content.growthDays, BabyWidgetTimelineContentBuilder.placeholderGrowthDays)
        XCTAssertEqual(content.date, referenceDate)
    }

    func testBuildFromSnapshotMapsSmallMediumLargeFields() {
        let referenceDate = makeWidgetTestDate(year: 2024, month: 6, day: 7, calendar: calendar)
        let snapshot = WidgetSnapshot(
            babyId: "baby_1",
            babyName: "豆豆",
            growthDays: 120,
            updatedAt: referenceDate,
            avatarThumbnailSmall: "thumbnails/avatar_baby_1_200.jpg",
            recentDays: [
                WidgetSnapshotDayEntry(
                    date: "2024-06-07",
                    photoId: "photo_today",
                    thumbnailSmall: "thumbnails/photo_today_200.jpg",
                    thumbnailLarge: "thumbnails/photo_today_600.jpg"
                ),
                WidgetSnapshotDayEntry(
                    date: "2024-06-06",
                    photoId: "photo_yesterday",
                    thumbnailSmall: "thumbnails/photo_yesterday_200.jpg",
                    thumbnailLarge: "thumbnails/photo_yesterday_600.jpg"
                ),
                WidgetSnapshotDayEntry(
                    date: "2024-06-05",
                    photoId: "photo_3",
                    thumbnailSmall: "thumbnails/photo_3_200.jpg",
                    thumbnailLarge: "thumbnails/photo_3_600.jpg"
                ),
                WidgetSnapshotDayEntry(
                    date: "2024-06-04",
                    photoId: "photo_4",
                    thumbnailSmall: "thumbnails/photo_4_200.jpg",
                    thumbnailLarge: "thumbnails/photo_4_600.jpg"
                ),
                WidgetSnapshotDayEntry(
                    date: "2024-06-03",
                    photoId: "photo_5",
                    thumbnailSmall: "thumbnails/photo_5_200.jpg",
                    thumbnailLarge: "thumbnails/photo_5_600.jpg"
                ),
            ]
        )

        let plan = BabyWidgetTimelineContentBuilder.build(
            from: snapshot,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(plan.content.babyId, "baby_1")
        XCTAssertEqual(plan.content.babyName, "豆豆")
        XCTAssertEqual(plan.content.growthDays, 120)
        XCTAssertEqual(plan.content.avatarThumbnailPath, "thumbnails/avatar_baby_1_200.jpg")
        XCTAssertEqual(plan.content.todayPhotoThumbnailPath, "thumbnails/photo_today_200.jpg")
        XCTAssertEqual(
            plan.content.weekPhotoThumbnailPaths,
            [
                "thumbnails/photo_today_200.jpg",
                "thumbnails/photo_yesterday_200.jpg",
                "thumbnails/photo_3_200.jpg",
                "thumbnails/photo_4_200.jpg",
            ]
        )
        XCTAssertFalse(plan.content.isPlaceholder)
    }

    func testBuildWithoutSnapshotReturnsEmptyState() {
        let referenceDate = makeWidgetTestDate(year: 2024, month: 6, day: 7, calendar: calendar)

        let plan = BabyWidgetTimelineContentBuilder.build(
            from: nil,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(plan.content.babyId, "")
        XCTAssertEqual(plan.content.growthDays, 0)
        XCTAssertNil(plan.content.avatarThumbnailPath)
        XCTAssertTrue(plan.content.weekPhotoThumbnailPaths.isEmpty)
    }

    func testNextRefreshDateIsStartOfNextDay() {
        let referenceDate = makeWidgetTestDate(year: 2024, month: 6, day: 7, hour: 15, calendar: calendar)
        let nextRefresh = BabyWidgetTimelineContentBuilder.nextRefreshDate(
            after: referenceDate,
            calendar: calendar
        )
        let expected = makeWidgetTestDate(year: 2024, month: 6, day: 8, hour: 0, calendar: calendar)

        XCTAssertEqual(nextRefresh, expected)
    }

    func testSwitchingBabyChangesTimelineIdentity() {
        let referenceDate = makeWidgetTestDate(year: 2024, month: 6, day: 7, calendar: calendar)
        let babyA = WidgetSnapshot(
            babyId: "baby_a",
            babyName: "A",
            growthDays: 10,
            updatedAt: referenceDate,
            recentDays: []
        )
        let babyB = WidgetSnapshot(
            babyId: "baby_b",
            babyName: "B",
            growthDays: 20,
            updatedAt: referenceDate,
            recentDays: []
        )

        let planA = BabyWidgetTimelineContentBuilder.build(
            from: babyA,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let planB = BabyWidgetTimelineContentBuilder.build(
            from: babyB,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertNotEqual(planA.content.babyId, planB.content.babyId)
        XCTAssertNotEqual(planA.content.babyName, planB.content.babyName)
        XCTAssertNotEqual(planA.content.growthDays, planB.content.growthDays)
    }
}
