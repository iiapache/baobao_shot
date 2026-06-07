import Foundation

/// 无 StoreKit 依赖的 IAP stub：生成后端可识别的 `mock:` JWS，供 Debug / 模拟器 / UI 测试联调。
public struct StubIAPStoreClient: IAPStoreClient, @unchecked Sendable {
    public static let defaultBundleID = "com.babycamera.app"

    public let bundleID: String
    private let transactionIDFactory: @Sendable () -> String
    private let lock = NSLock()
    private var unfinished: [IAPVerifiedTransaction] = []
    private var updatesContinuation: AsyncStream<IAPVerifiedTransaction>.Continuation?

    public init(
        bundleID: String = Self.defaultBundleID,
        transactionIDFactory: @escaping @Sendable () -> String = {
            String(Int.random(in: 2_000_000_000_000_000...2_999_999_999_999_999))
        }
    ) {
        self.bundleID = bundleID
        self.transactionIDFactory = transactionIDFactory
    }

    public func loadProducts(ids: Set<String>) async throws -> [IAPProduct] {
        ids.compactMap { productID in
            guard let credits = CreditIAPProductID.creditsByProductID[productID] else {
                return nil
            }
            return IAPProduct(
                id: productID,
                displayName: CreditIAPProductID.tierNameByProductID[productID] ?? productID,
                displayPrice: Self.stubDisplayPrice(for: productID),
                credits: credits
            )
        }
        .sorted { lhs, rhs in
            (CreditIAPProductID.creditsByProductID[lhs.id] ?? 0)
                < (CreditIAPProductID.creditsByProductID[rhs.id] ?? 0)
        }
    }

    public func purchase(productID: String) async throws -> IAPVerifiedTransaction {
        guard CreditIAPProductID.all.contains(productID)
            || SubscriptionProductID.isSubscriptionProduct(productID) else {
            throw IAPServiceError.productNotFound
        }

        let transactionID = transactionIDFactory()
        let storeTransactionID = UInt64(transactionID) ?? UInt64.random(in: 1...UInt64.max / 2)
        let signedTransaction = Self.makeMockSignedTransaction(
            transactionID: transactionID,
            productID: productID,
            bundleID: bundleID
        )
        let transaction = IAPVerifiedTransaction(
            transactionID: transactionID,
            productID: productID,
            signedTransaction: signedTransaction,
            storeTransactionID: storeTransactionID
        )

        lock.withLock {
            unfinished.append(transaction)
        }
        updatesContinuation?.yield(transaction)
        return transaction
    }

    public func unfinishedTransactions() async -> [IAPVerifiedTransaction] {
        lock.withLock { unfinished }
    }

    public func finish(transactionID: UInt64) async throws {
        lock.withLock {
            unfinished.removeAll { $0.storeTransactionID == transactionID }
        }
    }

    public func transactionUpdates() -> AsyncStream<IAPVerifiedTransaction> {
        AsyncStream { continuation in
            lock.withLock {
                updatesContinuation = continuation
            }
            continuation.onTermination = { [self] _ in
                lock.withLock {
                    updatesContinuation = nil
                }
            }
        }
    }

    /// 与 credit-sub-ad-svc `parseMockJWS` 对齐。
    public static func makeMockSignedTransaction(
        transactionID: String,
        productID: String,
        bundleID: String = defaultBundleID,
        purchaseDate: Date = Date(),
        subscriptionPeriodDays: Int = 30
    ) -> String {
        if SubscriptionProductID.isSubscriptionProduct(productID) {
            let purchaseMs = Int(purchaseDate.timeIntervalSince1970 * 1_000)
            let expiresMs = Int(
                purchaseDate.addingTimeInterval(TimeInterval(subscriptionPeriodDays * 86_400))
                    .timeIntervalSince1970 * 1_000
            )
            return "mock:\(transactionID):\(productID):\(transactionID):\(bundleID):\(purchaseMs):\(expiresMs)"
        }
        return "mock:\(transactionID):\(productID)"
    }

    private static func stubDisplayPrice(for productID: String) -> String {
        switch productID {
        case CreditIAPProductID.pack60:
            return "¥6"
        case CreditIAPProductID.pack330:
            return "¥30"
        case CreditIAPProductID.pack800:
            return "¥68"
        case CreditIAPProductID.pack2500:
            return "¥198"
        default:
            return "—"
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
