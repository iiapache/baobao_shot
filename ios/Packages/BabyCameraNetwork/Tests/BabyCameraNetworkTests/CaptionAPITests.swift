import XCTest
@testable import BabyCameraNetwork

final class CaptionAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testGenerateSuccess() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/caption/generate")
            return MockResponse(statusCode: 200, json: MockServer.captionGenerateSuccessJSON(remainingToday: 42))
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = CaptionAPI(client: client)

        let result = try await api.generate(
            CaptionGenerateRequest(
                babyId: "bb_test001",
                ageDays: 312,
                play: "ghibli_kid",
                location: "杭州"
            )
        )

        XCTAssertEqual(result.candidates.count, 3)
        XCTAssertEqual(result.candidates[0].text, "豆豆 · 第 312 天 · 化身吉卜力小主角 🌿")
        XCTAssertEqual(result.candidates[0].hashtags, ["#宝宝成长", "#吉卜力"])
        XCTAssertEqual(result.candidates[0].composedText, "豆豆 · 第 312 天 · 化身吉卜力小主角 🌿 #宝宝成长 #吉卜力")
        XCTAssertEqual(result.remainingToday, 42)
    }

    func testGenerateDailyLimitThrowsAPIError() async {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/caption/generate")
            return MockResponse(statusCode: 429, json: MockServer.captionDailyLimitJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = CaptionAPI(client: client)

        do {
            _ = try await api.generate(CaptionGenerateRequest(babyId: "bb_test001", ageDays: 10))
            XCTFail("expected APIError")
        } catch let error as APIError {
            XCTAssertEqual(error.code, .captionDailyLimit)
            XCTAssertEqual(error.httpStatusCode, 429)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
