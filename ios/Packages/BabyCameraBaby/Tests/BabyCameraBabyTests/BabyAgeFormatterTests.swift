import XCTest
@testable import BabyCameraBaby

final class BabyAgeFormatterTests: XCTestCase {
    private let birth = "2024-01-01"

    // MARK: - Phase 1: 出生第 N 天（1–99）

    func testBirthDayIsDayOne() {
        XCTAssertEqual(displayAge(on: "2024-01-01"), "出生第 1 天")
    }

    func testDay10() {
        XCTAssertEqual(displayAge(on: "2024-01-10"), "出生第 10 天")
    }

    func testDay99Boundary() {
        XCTAssertEqual(displayAge(on: "2024-04-08"), "出生第 99 天")
    }

    // MARK: - Phase 1 → Phase 2 boundary (99 / 100)

    func testDay100Boundary() {
        XCTAssertEqual(displayAge(on: "2024-04-09"), "3 个月 8 天")
    }

    // MARK: - Phase 2: N 个月 N 天（100–365 天，未满 1 岁）

    func testDay150() {
        XCTAssertEqual(displayAge(on: "2024-05-29"), "4 个月 28 天")
    }

    func testDay364Boundary() {
        XCTAssertEqual(displayAge(on: "2024-12-29"), "11 个月 28 天")
    }

    func testDay365Boundary() {
        XCTAssertEqual(displayAge(on: "2024-12-30"), "11 个月 29 天")
    }

    // MARK: - Phase 2 → Phase 3 boundary (满 1 岁)

    func testExactlyOneYear() {
        XCTAssertEqual(displayAge(on: "2025-01-01"), "1 岁")
    }

    func testOneYearWithExtraMonths() {
        XCTAssertEqual(displayAge(on: "2025-04-15"), "1 岁 3 个月")
    }

    // MARK: - Phase 3: N 岁 N 个月（1–3 岁）

    func testTwoYearsFiveMonths() {
        let olderBirth = "2022-01-01"
        XCTAssertEqual(
            BabyAgeFormatter.displayAge(birthDate: olderBirth, referenceDate: makeDate(year: 2024, month: 6, day: 1)),
            "2 岁 5 个月"
        )
    }

    func testJustUnderThreeYears() {
        XCTAssertEqual(displayAge(on: "2026-12-31"), "2 岁 11 个月")
    }

    func testExactlyThreeYears() {
        XCTAssertEqual(displayAge(on: "2027-01-01"), "3 岁 1月1日")
    }

    func testThreeYearsOneMonthUsesDateNotMonths() {
        XCTAssertEqual(displayAge(on: "2027-02-01"), "3 岁 2月1日")
    }

    // MARK: - Phase 4: N 岁 + 当天日期（3 岁以上）

    func testOverThreeYears() {
        XCTAssertEqual(displayAge(on: "2028-06-15"), "4 岁 6月15日")
    }

    // MARK: - Edge cases

    func testNotBornYet() {
        XCTAssertEqual(displayAge(on: "2023-12-31"), "未出生")
    }

    func testInvalidBirthDateReturnsOriginal() {
        XCTAssertEqual(BabyAgeFormatter.displayAge(birthDate: "invalid"), "invalid")
    }

    // MARK: - Helpers

    private func displayAge(on reference: String) -> String {
        BabyAgeFormatter.displayAge(birthDate: birth, referenceDate: makeDate(from: reference))
    }

    private func makeDate(from isoDate: String) -> Date {
        let parts = isoDate.split(separator: "-").compactMap { Int($0) }
        XCTAssertEqual(parts.count, 3)
        return makeDate(year: parts[0], month: parts[1], day: parts[2])
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        return components.date!
    }
}
