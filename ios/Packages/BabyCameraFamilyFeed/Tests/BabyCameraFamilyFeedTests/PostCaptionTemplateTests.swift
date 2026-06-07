import XCTest
@testable import BabyCameraFamilyFeed

final class PostCaptionTemplateTests: XCTestCase {
    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 10
        calendar = Calendar(identifier: .gregorian)
        referenceDate = calendar.date(from: components)!
    }

    func testDefaultCaptionWithAIPlayName() {
        let caption = PostCaptionTemplate.makeCaption(
            babyName: "豆豆",
            birthDate: "2024-01-01",
            aiPlayName: "吉卜力风",
            referenceDate: referenceDate
        )
        XCTAssertEqual(caption, "豆豆 · 第 10 天 · 吉卜力风")
    }

    func testCaptionWithoutAIPlayName() {
        let caption = PostCaptionTemplate.makeCaption(
            babyName: "糖糖",
            birthDate: "2024-01-01",
            aiPlayName: nil,
            referenceDate: referenceDate
        )
        XCTAssertEqual(caption, "糖糖 · 第 10 天")
    }

    func testGrowthDayCalculation() {
        XCTAssertEqual(
            PostCaptionTemplate.growthDay(
                birthDate: "2024-01-01",
                referenceDate: referenceDate,
                calendar: calendar
            ),
            10
        )
    }
}
