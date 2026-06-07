import XCTest
@testable import BabyCameraMilestone

final class MilestoneDateCalculatorTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calendar = cal
    }

    func testDayOffsetTriggerDateUsesBirthDayOneSemantics() {
        let birth = makeDate(year: 2025, month: 1, day: 10)
        let day3 = MilestoneDateCalculator.dayOffsetTriggerDate(
            birthDate: birth,
            dayOffset: 3,
            calendar: calendar
        )
        XCTAssertEqual(day3, makeDate(year: 2025, month: 1, day: 12))
    }

    func testOccurrencesWithin365DayWindow() {
        let birthDate = "2025-01-01"
        let reference = makeDate(year: 2025, month: 1, day: 1)
        let occurrences = MilestoneDateCalculator.occurrences(
            milestones: MilestoneCatalog.milestones,
            birthDate: birthDate,
            babyId: "baby-1",
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertFalse(occurrences.isEmpty)
        for item in occurrences {
            XCTAssertGreaterThan(item.triggerDate, calendar.startOfDay(for: reference))
            let horizon = calendar.date(byAdding: .day, value: 365, to: calendar.startOfDay(for: reference))!
            XCTAssertLessThanOrEqual(item.triggerDate, horizon)
        }
    }

    func testOccurrencesExcludePastDayOffsets() {
        let birthDate = "2024-06-01"
        let reference = makeDate(year: 2025, month: 6, day: 2)
        let occurrences = MilestoneDateCalculator.occurrences(
            milestones: MilestoneCatalog.milestones.filter { $0.trigger.kind == .dayOffset },
            birthDate: birthDate,
            babyId: "baby-1",
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertTrue(occurrences.isEmpty, "已过生日偏移节点不应再预约")
    }

    func testAnnualChildrenDayWithinHorizon() {
        let birthDate = "2025-03-01"
        let reference = makeDate(year: 2025, month: 3, day: 1)
        let childrenDay = MilestoneDefinition(
            id: "ms_children_day",
            name: "六一儿童节",
            trigger: MilestoneTrigger(kind: .annual, day: 1, month: 6),
            notificationTitle: "六一",
            notificationBody: "节日快乐",
            templateId: "tpl_birthday_03",
            sort: 1
        )
        let occurrences = MilestoneDateCalculator.occurrences(
            milestones: [childrenDay],
            birthDate: birthDate,
            babyId: "baby-1",
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(occurrences.count, 1)
        XCTAssertEqual(occurrences.first?.triggerDate, makeDate(year: 2025, month: 6, day: 1))
        XCTAssertEqual(
            occurrences.first?.notificationIdentifier,
            MilestoneNotificationIdentifier.make(babyId: "baby-1", milestoneId: "ms_children_day", yearSuffix: 2025)
        )
    }

    func testBirthdayAnnualSkipsFirstBirthday() {
        let birthDate = "2025-01-15"
        let reference = makeDate(year: 2025, month: 1, day: 1)
        let birthday = MilestoneCatalog.milestone(for: "ms_birthday")!
        let occurrences = MilestoneDateCalculator.occurrences(
            milestones: [birthday],
            birthDate: birthDate,
            babyId: "baby-1",
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(occurrences.count, 0, "出生日当天不算年度生日，周岁由 dayOffset 节点覆盖")
    }

    func testNotificationIdentifierDedupForSameDayMilestones() {
        let birthDate = "2025-01-01"
        let reference = makeDate(year: 2024, month: 12, day: 1)
        let firstBirthday = MilestoneCatalog.milestone(for: "ms_first_birthday")!
        let zhuazhou = MilestoneCatalog.milestone(for: "ms_zhuazhou")!
        let occurrences = MilestoneDateCalculator.occurrences(
            milestones: [firstBirthday, zhuazhou],
            birthDate: birthDate,
            babyId: "baby-1",
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(occurrences.count, 2)
        let identifiers = Set(occurrences.map(\.notificationIdentifier))
        XCTAssertEqual(identifiers.count, 2)
        XCTAssertEqual(occurrences[0].triggerDate, occurrences[1].triggerDate)
    }

    func testSchedulingHorizonIs365Days() {
        XCTAssertEqual(MilestoneDateCalculator.schedulingHorizonDays, 365)
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        return calendar.date(from: components)!
    }
}
