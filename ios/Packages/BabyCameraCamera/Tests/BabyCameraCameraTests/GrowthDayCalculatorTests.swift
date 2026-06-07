import XCTest
@testable import BabyCameraCamera

final class GrowthDayCalculatorTests: XCTestCase {
    func testBirthDayIsOne() {
        let takenAt = makeDate(year: 2024, month: 1, day: 1)
        XCTAssertEqual(GrowthDayCalculator.growthDay(birthDate: "2024-01-01", takenAt: takenAt), 1)
    }

    func testDayTen() {
        let takenAt = makeDate(year: 2024, month: 1, day: 10)
        XCTAssertEqual(GrowthDayCalculator.growthDay(birthDate: "2024-01-01", takenAt: takenAt), 10)
    }

    func testNotBornYetReturnsNil() {
        let takenAt = makeDate(year: 2023, month: 12, day: 31)
        XCTAssertNil(GrowthDayCalculator.growthDay(birthDate: "2024-01-01", takenAt: takenAt))
    }

    func testInvalidBirthDateReturnsNil() {
        let takenAt = makeDate(year: 2024, month: 6, day: 1)
        XCTAssertNil(GrowthDayCalculator.growthDay(birthDate: "invalid", takenAt: takenAt))
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
