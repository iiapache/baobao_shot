import Foundation
@testable import BabyCameraCredit

final class MockIAPStoreClient: IAPStoreClient, @unchecked Sendable {
    var products: [IAPProduct] = []
    var purchaseHandler: (@Sendable (String) async throws -> IAPVerifiedTransaction)?
    var unfinished: [IAPVerifiedTransaction] = []
    private(set) var finishedTransactionIDs: [UInt64] = []
    private var updatesContinuation: AsyncStream<IAPVerifiedTransaction>.Continuation?

    func loadProducts(ids: Set<String>) async throws -> [IAPProduct] {
        _ = ids
        return products
    }

    func purchase(productID: String) async throws -> IAPVerifiedTransaction {
        if let purchaseHandler {
            return try await purchaseHandler(productID)
        }
        throw IAPServiceError.productNotFound
    }

    func unfinishedTransactions() async -> [IAPVerifiedTransaction] {
        unfinished
    }

    func finish(transactionID: UInt64) async throws {
        finishedTransactionIDs.append(transactionID)
        unfinished.removeAll { $0.storeTransactionID == transactionID }
    }

    func transactionUpdates() -> AsyncStream<IAPVerifiedTransaction> {
        AsyncStream { continuation in
            updatesContinuation = continuation
        }
    }

    func emitUpdate(_ transaction: IAPVerifiedTransaction) {
        updatesContinuation?.yield(transaction)
    }
}

extension IAPVerifiedTransaction {
    static func fixture(
        transactionID: String = "2000000123456789",
        productID: String = CreditIAPProductID.pack330,
        signedTransaction: String = "mock-jws-token",
        storeTransactionID: UInt64 = 2_000_000_123_456_789
    ) -> IAPVerifiedTransaction {
        IAPVerifiedTransaction(
            transactionID: transactionID,
            productID: productID,
            signedTransaction: signedTransaction,
            storeTransactionID: storeTransactionID
        )
    }
}
