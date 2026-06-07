import BabyCameraCredit
import BabyCameraNetwork
import XCTest
@testable import BabyCameraAIPlay

final class CreditPreviewServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testPreviewUsesRemoteRatesWithoutCreditService() async throws {
        MockURLProtocol.register { request in
            switch request.url?.path {
            case "/v1/credits/balance":
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.creditBalanceJSON(balance: 100, signInAvailable: false)
                )
            case "/v1/credits/rates":
                return MockResponse(statusCode: 200, json: MockServer.creditRatesJSON(ghibliCost: 10))
            default:
                return nil
            }
        }

        let tokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
        let service = CreditPreviewService(
            configuration: CreditPreviewServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "preview-test"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            )
        )
        let play = AIPlay(id: "ghibli_kid", name: "宫崎骏风", kind: .image, creditCost: 8, available: true)

        let preview = try await service.preview(play: play, durationSeconds: nil)

        XCTAssertEqual(preview.costCredits, 10)
        XCTAssertEqual(preview.balance, 100)
        XCTAssertEqual(preview.balanceAfter, 90)
    }

    @MainActor
    func testPreviewDelegatesToCreditService() async throws {
        let tokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
        let creditService = PreviewMockCreditService(
            preview: CreditCostPreview(costCredits: 12, balance: 88, signInAvailable: true)
        )
        let service = CreditPreviewService(
            configuration: CreditPreviewServiceConfiguration(tokenStore: tokenStore),
            creditService: creditService
        )
        let play = AIPlay(id: "ghibli_kid", name: "宫崎骏风", kind: .image, creditCost: 8, available: true)

        let preview = try await service.preview(play: play, durationSeconds: nil)

        XCTAssertEqual(preview.costCredits, 12)
        XCTAssertEqual(preview.balance, 88)
        XCTAssertEqual(preview.signInHint, "今日签到可领 5–20 积分")
        XCTAssertEqual(creditService.lastLocalCost, 8)
    }
}

@MainActor
private final class PreviewMockCreditService: CreditServing {
    let preview: CreditCostPreview
    private(set) var lastLocalCost: Int?

    init(preview: CreditCostPreview) {
        self.preview = preview
    }

    var balance: Int = 0
    var signInAvailable: Bool = false
    var currentSignInStreak: Int = 0

    func refreshBalance() async throws {}
    func signIn() async throws -> SignInResult {
        throw CreditServiceError.notAuthenticated
    }
    func fetchTransactions(cursor: String?, limit: Int) async throws -> CreditTransactionsPage {
        CreditTransactionsPage(items: [], nextCursor: nil)
    }
    func bindWebSocketEvents(_ events: AsyncStream<AITaskBalanceEvent>) {}
    func unbindWebSocketEvents() {}
    func applyBalanceFromAITask(_ balanceAfter: Int) {
        balance = balanceAfter
    }
    func previewCost(playId: String, durationSeconds: Int?, localCost: Int) async throws -> CreditCostPreview {
        lastLocalCost = localCost
        return preview
    }
}
