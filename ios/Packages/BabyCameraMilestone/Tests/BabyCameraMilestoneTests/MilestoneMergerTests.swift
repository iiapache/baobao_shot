import XCTest
@testable import BabyCameraMilestone

final class MilestoneMergerTests: XCTestCase {
    private let birthDate = "2025-01-01"
    private let babyId = "baby-merge-test"
    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        calendar = Calendar(identifier: .gregorian)
        referenceDate = date("2025-01-01")
    }

    func testCalendarMarkedDayKeysIncludeBuiltinAndCustom() {
        let custom = [
            CustomMilestone(
                id: "ms_custom_1",
                babyId: babyId,
                name: "第一次游泳",
                date: date("2025-02-01")
            ),
        ]

        let entries = MilestoneMerger.mergedEntries(
            birthDate: birthDate,
            babyId: babyId,
            customMilestones: custom,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let markedDays = MilestoneMerger.calendarMarkedDayKeys(from: entries, calendar: calendar)

        XCTAssertTrue(markedDays.contains("2025-01-03"), "三朝（第 3 天）应被标记")
        XCTAssertTrue(markedDays.contains("2025-02-01"), "自定义里程碑日期应被标记")
        XCTAssertFalse(markedDays.isEmpty)
    }

    func testSortMergedBuiltinBeforeCustomOnSameDay() {
        let custom = [
            CustomMilestone(
                id: "ms_custom_same_day",
                babyId: babyId,
                name: "自定义同日",
                date: date("2025-01-03")
            ),
        ]

        let entries = MilestoneMerger.mergedEntries(
            birthDate: birthDate,
            babyId: babyId,
            customMilestones: custom,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let sameDayEntries = entries.filter { $0.dayKey(calendar: calendar) == "2025-01-03" }
        XCTAssertGreaterThanOrEqual(sameDayEntries.count, 2)
        XCTAssertFalse(sameDayEntries[0].isCustom, "同日内置节点应排在自定义之前")
        XCTAssertTrue(sameDayEntries.last?.isCustom == true)
    }

    func testSortMergedOrdersByDateAscending() {
        let custom = [
            CustomMilestone(id: "c2", babyId: babyId, name: "较晚", date: date("2025-03-01")),
            CustomMilestone(id: "c1", babyId: babyId, name: "较早", date: date("2025-02-01")),
        ]

        let entries = MilestoneMerger.mergedEntries(
            birthDate: birthDate,
            babyId: babyId,
            customMilestones: custom,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let customEntries = entries.compactMap { entry -> CustomMilestone? in
            if case let .custom(milestone) = entry { return milestone }
            return nil
        }
        XCTAssertEqual(customEntries.map(\.name), ["较早", "较晚"])
    }

    func testListAndCalendarShareSameMarkedDays() {
        let custom = [
            CustomMilestone(id: "c1", babyId: babyId, name: "标记日", date: date("2025-06-15")),
        ]

        let entries = MilestoneMerger.mergedEntries(
            birthDate: birthDate,
            babyId: babyId,
            customMilestones: custom,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let markedDays = MilestoneMerger.calendarMarkedDayKeys(from: entries, calendar: calendar)

        for entry in entries {
            XCTAssertTrue(markedDays.contains(entry.dayKey(calendar: calendar)))
        }
    }

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)!
    }
}
