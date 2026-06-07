import Foundation
import StoreKit

public protocol IAPStoreClient: Sendable {
    func loadProducts(ids: Set<String>) async throws -> [IAPProduct]
    func purchase(productID: String) async throws -> IAPVerifiedTransaction
    func unfinishedTransactions() async -> [IAPVerifiedTransaction]
    func finish(transactionID: UInt64) async throws
    func transactionUpdates() -> AsyncStream<IAPVerifiedTransaction>
}

public final class StoreKitPurchaseClient: IAPStoreClient, @unchecked Sendable {
    public init() {}

    public func loadProducts(ids: Set<String>) async throws -> [IAPProduct] {
        let products = try await Product.products(for: ids)
        return products
            .sorted { lhs, rhs in
                (CreditIAPProductID.creditsByProductID[lhs.id] ?? 0)
                    < (CreditIAPProductID.creditsByProductID[rhs.id] ?? 0)
            }
            .map { product in
                IAPProduct(
                    id: product.id,
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    credits: CreditIAPProductID.creditsByProductID[product.id] ?? 0,
                    tierName: CreditIAPProductID.tierNameByProductID[product.id]
                )
            }
    }

    public func purchase(productID: String) async throws -> IAPVerifiedTransaction {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw IAPServiceError.productNotFound
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            return try Self.mapVerified(verification)
        case .userCancelled:
            throw IAPServiceError.userCancelled
        case .pending:
            throw IAPServiceError.purchasePending
        @unknown default:
            throw IAPServiceError.purchaseFailed
        }
    }

    public func unfinishedTransactions() async -> [IAPVerifiedTransaction] {
        var transactions: [IAPVerifiedTransaction] = []
        for await verification in Transaction.unfinished {
            if let transaction = try? Self.mapVerified(verification) {
                transactions.append(transaction)
            }
        }
        return transactions
    }

    public func finish(transactionID: UInt64) async throws {
        for await verification in Transaction.unfinished {
            guard case .verified(let transaction) = verification else { continue }
            guard transaction.id == transactionID else { continue }
            await transaction.finish()
            return
        }
    }

    public func transactionUpdates() -> AsyncStream<IAPVerifiedTransaction> {
        AsyncStream { continuation in
            let task = Task {
                for await verification in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    if let transaction = try? Self.mapVerified(verification) {
                        continuation.yield(transaction)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func mapVerified(_ verification: VerificationResult<Transaction>) throws -> IAPVerifiedTransaction {
        switch verification {
        case .verified(let transaction):
            return IAPVerifiedTransaction(
                transactionID: String(transaction.id),
                productID: transaction.productID,
                signedTransaction: transaction.jwsRepresentation,
                storeTransactionID: transaction.id
            )
        case .unverified:
            throw IAPServiceError.unverifiedTransaction
        }
    }
}
