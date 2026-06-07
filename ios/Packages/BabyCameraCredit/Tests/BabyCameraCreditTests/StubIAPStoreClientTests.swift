import XCTest
@testable import BabyCameraCredit

final class StubIAPStoreClientTests: XCTestCase {
    func testLoadCreditProductsReturnsCatalog() async throws {
        let client = StubIAPStoreClient()
        let products = try await client.loadProducts(ids: CreditIAPProductID.all)

        XCTAssertEqual(products.count, 4)
        XCTAssertEqual(products.first?.id, CreditIAPProductID.pack60)
        XCTAssertEqual(products.first?.credits, 60)
    }

    func testPurchaseCreditGeneratesMockJWS() async throws {
        let client = StubIAPStoreClient(transactionIDFactory: { "2000000999888777" })
        let transaction = try await client.purchase(productID: CreditIAPProductID.pack330)

        XCTAssertEqual(transaction.transactionID, "2000000999888777")
        XCTAssertEqual(transaction.productID, CreditIAPProductID.pack330)
        XCTAssertEqual(
            transaction.signedTransaction,
            "mock:2000000999888777:\(CreditIAPProductID.pack330)"
        )
    }

    func testPurchaseSubscriptionGeneratesMockJWSWithExpiry() async throws {
        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let client = StubIAPStoreClient(
            transactionIDFactory: { "2000000987654321" }
        )
        let signed = StubIAPStoreClient.makeMockSignedTransaction(
            transactionID: "2000000987654321",
            productID: SubscriptionProductID.monthly,
            purchaseDate: purchaseDate
        )
        XCTAssertTrue(signed.hasPrefix("mock:2000000987654321:\(SubscriptionProductID.monthly):"))

        let transaction = try await client.purchase(productID: SubscriptionProductID.monthly)
        XCTAssertTrue(transaction.signedTransaction.hasPrefix("mock:"))
        XCTAssertTrue(transaction.signedTransaction.contains(SubscriptionProductID.monthly))
    }

    func testFinishRemovesUnfinishedTransaction() async throws {
        let client = StubIAPStoreClient(transactionIDFactory: { "2000000111222333" })
        let transaction = try await client.purchase(productID: CreditIAPProductID.pack60)

        var unfinished = await client.unfinishedTransactions()
        XCTAssertEqual(unfinished.count, 1)

        try await client.finish(transactionID: transaction.storeTransactionID)

        unfinished = await client.unfinishedTransactions()
        XCTAssertTrue(unfinished.isEmpty)
    }

    func testUnknownProductThrows() async {
        let client = StubIAPStoreClient()

        do {
            _ = try await client.purchase(productID: "unknown.product")
            XCTFail("expected productNotFound")
        } catch IAPServiceError.productNotFound {
            XCTAssertTrue(true)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
