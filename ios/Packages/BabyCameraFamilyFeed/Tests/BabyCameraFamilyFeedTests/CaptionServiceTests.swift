import BabyCameraNetwork
import XCTest
@testable import BabyCameraFamilyFeed

final class CaptionServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testGenerateSuccessReturnsThreeCandidates() async {
        MockURLProtocol.register { _ in
            MockResponse(statusCode: 200, json: MockServer.captionGenerateSuccessJSON(remainingToday: 12))
        }

        let service = makeService()
        let outcome = await service.generate(makeInput())

        guard case let .success(candidates, remainingToday) = outcome else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(candidates.count, 3)
        XCTAssertEqual(remainingToday, 12)
    }

    func testDailyLimitReturnsFallbackCaption() async {
        MockURLProtocol.register { _ in
            MockResponse(statusCode: 429, json: MockServer.captionDailyLimitJSON())
        }

        let service = makeService()
        let outcome = await service.generate(makeInput(aiPlayName: "吉卜力风"))

        guard case let .dailyLimitExceeded(message, fallbackCaption) = outcome else {
            return XCTFail("expected dailyLimitExceeded")
        }
        XCTAssertEqual(message, CaptionService.dailyLimitMessage)
        XCTAssertEqual(fallbackCaption, "豆豆 · 第 10 天 · 吉卜力风")
    }

    func testNetworkFailureDegradesToDefaultTemplate() async {
        MockURLProtocol.register { _ in nil }

        let service = makeService()
        let outcome = await service.generate(makeInput(aiPlayName: "吉卜力风"))

        guard case let .degraded(fallbackCaption) = outcome else {
            return XCTFail("expected degraded")
        }
        XCTAssertEqual(fallbackCaption, "豆豆 · 第 10 天 · 吉卜力风")
    }

    func testInvalidBirthDateDegradesWithoutNetworkCall() async {
        var called = false
        MockURLProtocol.register { _ in
            called = true
            return MockResponse(statusCode: 200, json: MockServer.captionGenerateSuccessJSON())
        }

        let service = makeService()
        let input = CaptionGenerateInput(
            babyId: "bb_test",
            babyName: "豆豆",
            birthDate: "invalid-date",
            aiPlayName: "吉卜力风",
            referenceDate: referenceDate
        )
        let outcome = await service.generate(input)

        guard case let .degraded(fallbackCaption) = outcome else {
            return XCTFail("expected degraded")
        }
        XCTAssertEqual(fallbackCaption, "豆豆 · 第 ? 天 · 吉卜力风")
        XCTAssertFalse(called)
    }

    private var referenceDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar.date(from: DateComponents(year: 2024, month: 1, day: 10))!
    }

    private func makeInput(aiPlayName: String? = nil) -> CaptionGenerateInput {
        CaptionGenerateInput(
            babyId: "bb_test",
            babyName: "豆豆",
            birthDate: "2024-01-01",
            aiPlayId: "ghibli_kid",
            aiPlayName: aiPlayName,
            referenceDate: referenceDate
        )
    }

    private func makeService() -> CaptionService {
        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        return CaptionService(captionAPI: CaptionAPI(client: client))
    }
}
