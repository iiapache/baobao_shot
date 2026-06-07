import BabyCameraNetwork
import XCTest
@testable import BabyCameraCredit

final class IAPServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testPurchaseVerifyAndFinish() async throws {
        let transaction = IAPVerifiedTransaction.fixture()
        let store = MockIAPStoreClient()
        store.purchaseHandler = { _ in transaction }

        var verifyCount = 0
        MockURLProtocol.register { request in
            verifyCount += 1
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/credits/iap-verify")
            return MockResponse(statusCode: 200, json: MockServer.iapVerifySuccessJSON())
        }

        let service = makeService(store: store)
        let outcome = try await service.purchase(productID: CreditIAPProductID.pack330)

        XCTAssertEqual(outcome.verifyData.grantedCredits, 330)
        XCTAssertEqual(store.finishedTransactionIDs, [transaction.storeTransactionID])
        XCTAssertEqual(verifyCount, 1)
    }

    func testDuplicateResponseStillFinishes() async throws {
        let transaction = IAPVerifiedTransaction.fixture()
        let store = MockIAPStoreClient()
        store.purchaseHandler = { _ in transaction }

        MockURLProtocol.register { _ in
            MockResponse(
                statusCode: 200,
                json: MockServer.iapVerifySuccessJSON(duplicate: true)
            )
        }

        let service = makeService(store: store)
        _ = try await service.purchase(productID: CreditIAPProductID.pack330)

        XCTAssertEqual(store.finishedTransactionIDs, [transaction.storeTransactionID])
    }

    func testRetryOnServerErrorThenSucceeds() async throws {
        let transaction = IAPVerifiedTransaction.fixture()
        let store = MockIAPStoreClient()
        store.purchaseHandler = { _ in transaction }

        var attempts = 0
        MockURLProtocol.register { _ in
            attempts += 1
            if attempts == 1 {
                return MockResponse(statusCode: 503, json: MockServer.sysInternalJSON())
            }
            return MockResponse(statusCode: 200, json: MockServer.iapVerifySuccessJSON())
        }

        let config = IAPServiceConfiguration(
            tokenStore: makeTokenStore(),
            session: MockURLProtocol.makeSession(),
            maxVerifyRetries: 3,
            retryBaseDelay: 0.01
        )
        let service = IAPService(
            configuration: config,
            storeClient: store,
            pendingStore: PendingIAPReceiptStore(
                defaults: UserDefaults(suiteName: "IAPServiceTests.retry")!,
                key: "pending"
            ),
            clientFactory: { tokenStore in
                makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
            }
        )

        _ = try await service.purchase(productID: CreditIAPProductID.pack330)

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(store.finishedTransactionIDs, [transaction.storeTransactionID])
    }

    func testVerifyFailureDoesNotFinish() async throws {
        let transaction = IAPVerifiedTransaction.fixture()
        let store = MockIAPStoreClient()
        store.purchaseHandler = { _ in transaction }

        MockURLProtocol.register { _ in
            MockResponse(statusCode: 422, json: MockServer.iapVerifyFailedJSON())
        }

        let defaults = UserDefaults(suiteName: "IAPServiceTests.fail")!
        defaults.removePersistentDomain(forName: "IAPServiceTests.fail")
        let pendingStore = PendingIAPReceiptStore(defaults: defaults, key: "pending")

        let service = makeService(store: store, pendingStore: pendingStore)

        do {
            _ = try await service.purchase(productID: CreditIAPProductID.pack330)
            XCTFail("expected verify failure")
        } catch IAPServiceError.nonRetriableVerifyFailure {
            XCTAssertTrue(store.finishedTransactionIDs.isEmpty)
            XCTAssertTrue(pendingStore.loadAll().isEmpty)
        }
    }

    func testBootstrapProcessesUnfinishedTransactions() async throws {
        let transaction = IAPVerifiedTransaction.fixture(transactionID: "tx_unfinished")
        let store = MockIAPStoreClient()
        store.unfinished = [transaction]

        MockURLProtocol.register { _ in
            MockResponse(statusCode: 200, json: MockServer.iapVerifySuccessJSON(transactionId: "tx_unfinished"))
        }

        let service = makeService(store: store)
        service.start()

        try await Task.sleep(nanoseconds: 200_000_000)
        service.stop()

        XCTAssertEqual(store.finishedTransactionIDs, [transaction.storeTransactionID])
    }

    func testRetryPendingUploadsOnNextLaunch() async throws {
        let transaction = IAPVerifiedTransaction.fixture(transactionID: "tx_pending")
        let store = MockIAPStoreClient()

        let defaults = UserDefaults(suiteName: "IAPServiceTests.pending")!
        defaults.removePersistentDomain(forName: "IAPServiceTests.pending")
        let pendingStore = PendingIAPReceiptStore(defaults: defaults, key: "pending")
        pendingStore.save(transaction)

        var verifyCount = 0
        MockURLProtocol.register { _ in
            verifyCount += 1
            return MockResponse(
                statusCode: 200,
                json: MockServer.iapVerifySuccessJSON(transactionId: "tx_pending")
            )
        }

        let service = makeService(store: store, pendingStore: pendingStore)
        await service.retryPendingUploads()

        XCTAssertEqual(verifyCount, 1)
        XCTAssertEqual(store.finishedTransactionIDs, [transaction.storeTransactionID])
        XCTAssertTrue(pendingStore.loadAll().isEmpty)
    }

    private func makeTokenStore() -> TokenStore {
        let tokenStore = KeychainTokenStore()
        tokenStore.save(TokenPair(accessToken: "access", refreshToken: "refresh"))
        return tokenStore
    }

    private func makeService(
        store: MockIAPStoreClient,
        pendingStore: PendingIAPReceiptStore? = nil
    ) -> IAPService {
        let defaults = UserDefaults(suiteName: "IAPServiceTests.\(UUID().uuidString)")!
        let pending = pendingStore ?? PendingIAPReceiptStore(defaults: defaults, key: "pending")
        let config = IAPServiceConfiguration(
            tokenStore: makeTokenStore(),
            session: MockURLProtocol.makeSession(),
            maxVerifyRetries: 3,
            retryBaseDelay: 0.01
        )
        return IAPService(
            configuration: config,
            storeClient: store,
            pendingStore: pending,
            clientFactory: { tokenStore in
                makeAuthenticatedClient(tokenStore: tokenStore, session: MockURLProtocol.makeSession())
            }
        )
    }
}

private extension MockServer {
    static func iapVerifyFailedJSON() -> String {
        """
        {
          "code": "IAP_VERIFY_FAILED",
          "message": "iap verification failed",
          "requestId": "req_iap_verify_fail"
        }
        """
    }

    static func sysInternalJSON() -> String {
        """
        {
          "code": "SYS_INTERNAL",
          "message": "internal error",
          "requestId": "req_sys_internal"
        }
        """
    }
}
