import XCTest
@testable import Widgets

final class WidgetRepresentativePhotoSelectorTests: XCTestCase {
    private let calendar = makeWidgetTestCalendar()

    func testSelectsMostRecentPhotoPerDayForLastSevenDays() {
        let referenceDate = makeWidgetTestDate(year: 2024, month: 6, day: 7, calendar: calendar)
        let photos = [
            WidgetSnapshotPhotoCandidate(
                photoId: "day7_morning",
                takenAt: makeWidgetTestDate(year: 2024, month: 6, day: 7, hour: 9, calendar: calendar),
                sourceImageURL: URL(fileURLWithPath: "/tmp/day7_morning.jpg")
            ),
            WidgetSnapshotPhotoCandidate(
                photoId: "day7_evening",
                takenAt: makeWidgetTestDate(year: 2024, month: 6, day: 7, hour: 20, calendar: calendar),
                sourceImageURL: URL(fileURLWithPath: "/tmp/day7_evening.jpg")
            ),
            WidgetSnapshotPhotoCandidate(
                photoId: "day6_only",
                takenAt: makeWidgetTestDate(year: 2024, month: 6, day: 6, hour: 15, calendar: calendar),
                sourceImageURL: URL(fileURLWithPath: "/tmp/day6_only.jpg")
            ),
            WidgetSnapshotPhotoCandidate(
                photoId: "day1_only",
                takenAt: makeWidgetTestDate(year: 2024, month: 6, day: 1, hour: 10, calendar: calendar),
                sourceImageURL: URL(fileURLWithPath: "/tmp/day1_only.jpg")
            ),
        ]

        let selected = WidgetRepresentativePhotoSelector.select(
            photos: photos,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(selected.map(\.photoId), ["day7_evening", "day6_only", "day1_only"])
    }

    func testSkipsDaysWithoutPhotos() {
        let referenceDate = makeWidgetTestDate(year: 2024, month: 6, day: 3, calendar: calendar)
        let photos = [
            WidgetSnapshotPhotoCandidate(
                photoId: "today",
                takenAt: makeWidgetTestDate(year: 2024, month: 6, day: 3, calendar: calendar),
                sourceImageURL: URL(fileURLWithPath: "/tmp/today.jpg")
            ),
        ]

        let selected = WidgetRepresentativePhotoSelector.select(
            photos: photos,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(selected.first?.photoId, "today")
    }
}
