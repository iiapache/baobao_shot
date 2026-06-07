import Database
import XCTest
@testable import BabyCameraTimeline

final class TimelineGroupingTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.locale = Locale(identifier: "zh_CN")
        calendar = cal
    }

    func testEmptyListReturnsNoSections() {
        let sections = TimelineGrouping.group(
            photos: [],
            scale: .day,
            calendar: calendar
        )
        XCTAssertTrue(sections.isEmpty)

        let rows = TimelineGrouping.makeRows(
            photos: [],
            scale: .month,
            calendar: calendar
        )
        XCTAssertTrue(rows.isEmpty)
    }

    func testPhotosSortedDescendingWithinAndAcrossSections() {
        let photos = [
            makePhoto(id: "p1", takenAt: ts(2024, 3, 15, 10)),
            makePhoto(id: "p2", takenAt: ts(2024, 3, 15, 18)),
            makePhoto(id: "p3", takenAt: ts(2024, 3, 10, 12)),
        ]

        let sections = TimelineGrouping.group(
            photos: photos.shuffled(),
            scale: .day,
            calendar: calendar
        )

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].photos.map(\.id), ["p2", "p1"])
        XCTAssertEqual(sections[1].photos.map(\.id), ["p3"])
    }

    func testCrossMonthBoundary() {
        let photos = [
            makePhoto(id: "jan", takenAt: ts(2024, 1, 31, 23)),
            makePhoto(id: "feb", takenAt: ts(2024, 2, 1, 1)),
        ]

        let sections = TimelineGrouping.group(
            photos: photos,
            scale: .month,
            calendar: calendar
        )

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].id, "2024-02")
        XCTAssertEqual(sections[1].id, "2024-01")
        XCTAssertEqual(sections[0].photos.map(\.id), ["feb"])
        XCTAssertEqual(sections[1].photos.map(\.id), ["jan"])
    }

    func testCrossYearBoundary() {
        let photos = [
            makePhoto(id: "y2023", takenAt: ts(2023, 12, 31, 20)),
            makePhoto(id: "y2024", takenAt: ts(2024, 1, 1, 8)),
        ]

        let sections = TimelineGrouping.group(
            photos: photos,
            scale: .year,
            calendar: calendar
        )

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].id, "2024")
        XCTAssertEqual(sections[1].id, "2023")
    }

    func testDayViewGroupsSameCalendarDay() {
        let photos = [
            makePhoto(id: "morning", takenAt: ts(2024, 6, 6, 8)),
            makePhoto(id: "evening", takenAt: ts(2024, 6, 6, 20)),
            makePhoto(id: "next", takenAt: ts(2024, 6, 7, 9)),
        ]

        let sections = TimelineGrouping.group(
            photos: photos,
            scale: .day,
            calendar: calendar
        )

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].photos.count, 1)
        XCTAssertEqual(sections[0].photos[0].id, "next")
        XCTAssertEqual(sections[1].photos.map(\.id), ["evening", "morning"])
    }

    func testAllScaleSingleSectionWithoutHeadersInRows() {
        let photos = [
            makePhoto(id: "a", takenAt: ts(2024, 1, 1)),
            makePhoto(id: "b", takenAt: ts(2024, 2, 1)),
        ]

        let sections = TimelineGrouping.group(
            photos: photos,
            scale: .all,
            calendar: calendar
        )
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].photos.map(\.id), ["b", "a"])

        let rows = TimelineGrouping.makeRows(
            photos: photos,
            scale: .all,
            calendar: calendar
        )
        XCTAssertFalse(rows.contains { if case .sectionHeader = $0 { return true }; return false })
        XCTAssertEqual(rows.count, 2)
    }

    func testMakeRowsIncludesSectionHeadersForDayScale() {
        let photos = [
            makePhoto(id: "p1", takenAt: ts(2024, 5, 1)),
            makePhoto(id: "p2", takenAt: ts(2024, 5, 2)),
        ]

        let rows = TimelineGrouping.makeRows(
            photos: photos,
            scale: .day,
            calendar: calendar
        )

        XCTAssertEqual(rows.count, 4)
        if case .sectionHeader = rows[0] {
            // ok
        } else {
            XCTFail("Expected section header first")
        }
    }

    // MARK: - Helpers

    private func makePhoto(id: String, takenAt: Int64) -> PhotoRecord {
        PhotoRecord(
            id: id,
            babyIds: ["baby_1"],
            userId: "user_1",
            takenAt: takenAt,
            sha256: "hash-\(id)",
            filePath: "/tmp/\(id).heic"
        )
    }

    private func ts(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Int64 {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        let date = calendar.date(from: components)!
        return Int64(date.timeIntervalSince1970)
    }
}

final class TimelineVirtualDataSourceTests: XCTestCase {
    func testShouldLoadMoreNearEnd() {
        var source = TimelineVirtualDataSource(pageSize: 10)
        let rows = (0..<20).map { TimelineRow.photo(TimelinePhotoItem(id: "\($0)", takenAt: Int64($0), filePath: "/\($0)")) }
        source.reset(rows: rows, loadedPhotoCount: 20, hasMore: true)

        XCTAssertFalse(source.shouldLoadMore(visibleIndex: 0))
        XCTAssertTrue(source.shouldLoadMore(visibleIndex: 15))
    }

    func testRowsInRangeClampsToBounds() {
        var source = TimelineVirtualDataSource()
        source.reset(rows: [
            .photo(TimelinePhotoItem(id: "1", takenAt: 1, filePath: "/1")),
            .photo(TimelinePhotoItem(id: "2", takenAt: 2, filePath: "/2")),
        ], loadedPhotoCount: 2, hasMore: false)

        XCTAssertEqual(source.rows(in: 0..<1).count, 1)
        XCTAssertEqual(source.rows(in: 5..<10).count, 0)
    }
}

final class TimelineViewModelTests: XCTestCase {
    @MainActor
    func testReloadBuildsSectionsForCurrentBaby() async {
        let store = CurrentBabyEnvironment(restorePersistedSelection: false)
        store.select(babyId: "baby_1")

        let photos = [
            PhotoRecord(
                id: "p1",
                babyIds: ["baby_1"],
                userId: "u1",
                takenAt: 1_705_315_200, // 2024-01-15
                sha256: "a",
                filePath: "/p1.heic"
            ),
            PhotoRecord(
                id: "p2",
                babyIds: ["baby_1"],
                userId: "u1",
                takenAt: 1_704_228_800, // 2024-01-03
                sha256: "b",
                filePath: "/p2.heic"
            ),
        ]
        let source = InMemoryTimelinePhotoSource(photos: photos, babyId: "baby_1")
        let vm = TimelineViewModel(photoSource: source, currentBabyStore: store)

        await vm.reload()

        XCTAssertEqual(vm.sections.count, 2)
        XCTAssertFalse(vm.rows.isEmpty)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func testScaleChangeRebuildsRows() async {
        let store = CurrentBabyEnvironment(restorePersistedSelection: false)
        store.select(babyId: "baby_1")

        let photos = (1...3).map { index in
            PhotoRecord(
                id: "p\(index)",
                babyIds: ["baby_1"],
                userId: "u1",
                takenAt: Int64(1_700_000_000 + index),
                sha256: "h\(index)",
                filePath: "/p\(index).heic"
            )
        }
        let vm = TimelineViewModel(
            photoSource: InMemoryTimelinePhotoSource(photos: photos),
            currentBabyStore: store
        )
        await vm.reload()

        let dayRowCount = vm.rows.count
        vm.setScale(.all)
        XCTAssertEqual(vm.rows.count, 3)
        XCTAssertLessThan(vm.rows.count, dayRowCount)
    }
}
