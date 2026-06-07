import XCTest
@testable import BabyCameraNetwork

final class CreditsAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testBalance() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/credits/balance")
            return MockResponse(statusCode: 200, json: MockServer.creditBalanceJSON(balance: 42, signInAvailable: false))
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = CreditsAPI(client: client)

        let balance = try await api.balance()
        XCTAssertEqual(balance.balance, 42)
        XCTAssertFalse(balance.signInAvailable)
    }

    func testTransactionsPagination() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/credits/transactions")
            let query = request.url?.query ?? ""
            if query.contains("cursor=page2") {
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.creditTransactionsJSON(
                        items: [
                            CreditTransactionItem(
                                id: "txn_003",
                                type: "refund",
                                amount: 8,
                                balanceAfter: 50,
                                createdAt: "2026-06-06T10:00:00Z"
                            ),
                        ],
                        nextCursor: nil
                    )
                )
            }
            XCTAssertTrue(query.contains("limit=2"))
            return MockResponse(statusCode: 200, json: MockServer.creditTransactionsJSON(nextCursor: "page2"))
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = CreditsAPI(client: client)

        let page1 = try await api.transactions(limit: 2)
        XCTAssertEqual(page1.items.count, 2)
        XCTAssertEqual(page1.nextCursor, "page2")

        let page2 = try await api.transactions(cursor: page1.nextCursor, limit: 2)
        XCTAssertEqual(page2.items.count, 1)
        XCTAssertEqual(page2.items[0].type, "refund")
        XCTAssertNil(page2.nextCursor)
    }

    func testIAPVerify() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/credits/iap-verify")
            return MockResponse(statusCode: 200, json: MockServer.iapVerifySuccessJSON())
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = CreditsAPI(client: client)

        let result = try await api.iapVerify(
            IAPVerifyRequest(
                transactionId: "2000000123456789",
                signedTransaction: "mock-jws",
                productId: "credit_pack_330"
            )
        )
        XCTAssertEqual(result.grantedCredits, 330)
        XCTAssertEqual(result.balanceAfter, 430)
        XCTAssertEqual(result.transactionId, "2000000123456789")
    }

    func testAdRewardReport() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/credits/ad-reward")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Nonce"), "nonce-ad-001")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Timestamp"), "1718678400000")
            return MockResponse(statusCode: 200, json: MockServer.adRewardSuccessJSON(
                grantedCredits: 5,
                balanceAfter: 105
            ))
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = CreditsAPI(client: client)

        let result = try await api.adReward(
            AdRewardRequest(
                network: "pangle",
                placementId: "slot_rewarded",
                transId: "client-trans-001",
                idfv: "IDFV-TEST-001"
            ),
            context: AdRewardRequestContext(nonce: "nonce-ad-001", timestampMs: 1_718_678_400_000)
        )
        XCTAssertEqual(result.grantedCredits, 5)
        XCTAssertEqual(result.balanceAfter, 105)
        XCTAssertEqual(result.ledgerId, "led_ad_reward_001")
    }

    func testSignIn() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/credits/sign-in")
            return MockResponse(
                statusCode: 200,
                json: MockServer.creditSignInJSON(
                    grantedCredits: 8,
                    balanceAfter: 108,
                    streak: 4
                )
            )
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = CreditsAPI(client: client)

        let result = try await api.signIn()
        XCTAssertEqual(result.grantedCredits, 8)
        XCTAssertEqual(result.balanceAfter, 108)
        XCTAssertEqual(result.streak, 4)
    }

    func testRates() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/credits/rates")
            return MockResponse(statusCode: 200, json: MockServer.creditRatesJSON(ghibliCost: 8))
        }

        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        let client = makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
        let api = CreditsAPI(client: client)

        let rates = try await api.rates()
        XCTAssertEqual(rates.version, "20250606001")
        XCTAssertEqual(rates.cost(for: "ghibli_kid", durationSeconds: nil), 8)
        XCTAssertEqual(rates.cost(for: "video_walk", durationSeconds: 5), 60)
    }
}
