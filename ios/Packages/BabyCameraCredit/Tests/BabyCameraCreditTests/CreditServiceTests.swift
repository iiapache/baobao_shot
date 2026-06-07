import BabyCameraNetwork
import XCTest
@testable import BabyCameraCredit

@MainActor
final class CreditServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeService(
        tokenStore: TokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")
    ) -> CreditService {
        CreditService(
            configuration: CreditServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            )
        )
    }

    func testRefreshBalanceViaRPC() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/credits/balance" else { return nil }
            return MockResponse(statusCode: 200, json: MockServer.creditBalanceJSON(balance: 88, signInAvailable: true))
        }

        let service = makeService()
        try await service.refreshBalance()

        XCTAssertEqual(service.balance, 88)
        XCTAssertTrue(service.signInAvailable)
    }

    func testFetchTransactionsPagination() async throws {
        var page = 0
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/credits/transactions" else { return nil }
            let query = request.url?.query ?? ""
            if query.contains("cursor=cursor_page_2") {
                page = 2
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.creditTransactionsJSON(
                        items: [
                            CreditTransactionItem(
                                id: "txn_003",
                                type: "refund",
                                amount: 8,
                                refKind: "ai_task",
                                refId: "tsk_001",
                                balanceAfter: 120,
                                createdAt: "2026-06-06T10:00:00Z"
                            ),
                        ],
                        nextCursor: nil
                    )
                )
            }
            page = 1
            return MockResponse(statusCode: 200, json: MockServer.creditTransactionsJSON())
        }

        let service = makeService()
        let firstPage = try await service.fetchTransactions(cursor: nil, limit: 2)
        XCTAssertEqual(firstPage.items.count, 2)
        XCTAssertEqual(firstPage.nextCursor, "cursor_page_2")

        let secondPage = try await service.fetchTransactions(cursor: firstPage.nextCursor, limit: 2)
        XCTAssertEqual(page, 2)
        XCTAssertEqual(secondPage.items.count, 1)
        XCTAssertNil(secondPage.nextCursor)
        XCTAssertEqual(secondPage.items[0].type, .refund)
    }

    func testWebSocketBalanceUpdate() async {
        let service = makeService()
        XCTAssertEqual(service.balance, 0)

        let (stream, continuation) = AsyncStream<AITaskBalanceEvent>.makeStream()
        service.bindWebSocketEvents(stream)

        continuation.yield(AITaskBalanceEvent(taskId: "tsk_ws_001", balanceAfter: 73))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(service.balance, 73)

        continuation.finish()
        service.unbindWebSocketEvents()
    }

    func testRPCOverridesStaleWebSocketBalance() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/credits/balance" else { return nil }
            return MockResponse(statusCode: 200, json: MockServer.creditBalanceJSON(balance: 100, signInAvailable: false))
        }

        let service = makeService()
        service.applyBalance(80, channel: .webSocket)
        try await service.refreshBalance()

        XCTAssertEqual(service.balance, 100)
    }

    func testNotAuthenticatedThrows() async {
        let service = makeService(tokenStore: InMemoryTokenStore())

        do {
            try await service.refreshBalance()
            XCTFail("expected not authenticated")
        } catch let error as CreditServiceError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSignInGrantsCreditsAndUpdatesStreak() async throws {
        MockURLProtocol.register { request in
            guard request.url?.path == "/v1/credits/sign-in" else { return nil }
            XCTAssertEqual(request.httpMethod, "POST")
            return MockResponse(
                statusCode: 200,
                json: MockServer.creditSignInJSON(
                    grantedCredits: 7,
                    balanceAfter: 107,
                    streak: 3,
                    ledgerId: "led_signin_003"
                )
            )
        }

        let service = makeService()
        try await service.signIn()

        XCTAssertEqual(service.balance, 107)
        XCTAssertFalse(service.signInAvailable)
        XCTAssertEqual(service.currentSignInStreak, 3)
    }

    func testPreviewCostUsesRemoteRatesAndBalance() async throws {
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

        let service = makeService()
        let preview = try await service.previewCost(
            playId: "ghibli_kid",
            durationSeconds: nil,
            localCost: 8
        )

        XCTAssertEqual(preview.costCredits, 10)
        XCTAssertEqual(preview.balance, 100)
        XCTAssertEqual(preview.balanceAfter, 90)
        XCTAssertTrue(preview.hasSufficientCredit)
    }

    func testPreviewCostFallsBackToLocalWhenRatesMiss() async throws {
        MockURLProtocol.register { request in
            switch request.url?.path {
            case "/v1/credits/balance":
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.creditBalanceJSON(balance: 5, signInAvailable: true)
                )
            case "/v1/credits/rates":
                return MockResponse(statusCode: 200, json: MockServer.creditRatesJSON())
            default:
                return nil
            }
        }

        let service = makeService()
        let preview = try await service.previewCost(
            playId: "unknown_play",
            durationSeconds: nil,
            localCost: 8
        )

        XCTAssertEqual(preview.costCredits, 8)
        XCTAssertFalse(preview.hasSufficientCredit)
        XCTAssertTrue(preview.signInAvailable)
    }

    func testApplyBalanceFromAITask() async {
        let service = makeService()
        service.applyBalanceFromAITask(92)
        XCTAssertEqual(service.balance, 92)
    }
}
