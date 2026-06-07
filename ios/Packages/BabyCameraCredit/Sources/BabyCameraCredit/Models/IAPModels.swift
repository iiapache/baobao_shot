import Foundation

/// PRD §4.11.2 充值档位，与后端 `iap.DefaultProductCatalog` 对齐。
public enum CreditIAPProductID {
    public static let pack60 = "credit_pack_60"
    public static let pack330 = "credit_pack_330"
    public static let pack800 = "credit_pack_800"
    public static let pack2500 = "credit_pack_2500"

    public static let all: Set<String> = [pack60, pack330, pack800, pack2500]

    public static let creditsByProductID: [String: Int] = [
        pack60: 60,
        pack330: 330,
        pack800: 800,
        pack2500: 2500,
    ]

    /// PRD §4.11.2 档位名称，与后端 `rates.manifest.json` 一致。
    public static let tierNameByProductID: [String: String] = [
        pack60: "体验装",
        pack330: "入门装",
        pack800: "常用装",
        pack2500: "大礼包",
    ]
}

public struct IAPProduct: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let displayPrice: String
    public let credits: Int
    public let tierName: String?

    public init(
        id: String,
        displayName: String,
        displayPrice: String,
        credits: Int,
        tierName: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.credits = credits
        self.tierName = tierName ?? CreditIAPProductID.tierNameByProductID[id]
    }
}

/// StoreKit 校验通过的 consumable 交易快照，用于上送与 finish。
public struct IAPVerifiedTransaction: Sendable, Equatable, Codable {
    public let transactionID: String
    public let productID: String
    public let signedTransaction: String
    public let storeTransactionID: UInt64

    public init(
        transactionID: String,
        productID: String,
        signedTransaction: String,
        storeTransactionID: UInt64
    ) {
        self.transactionID = transactionID
        self.productID = productID
        self.signedTransaction = signedTransaction
        self.storeTransactionID = storeTransactionID
    }
}

public enum IAPServiceError: Error, Equatable, Sendable {
    case notAuthenticated
    case productNotFound
    case userCancelled
    case purchasePending
    case purchaseFailed
    case unverifiedTransaction
    case verifyFailed
    case nonRetriableVerifyFailure
}

public struct IAPVerifyOutcome: Sendable, Equatable {
    public let transaction: IAPVerifiedTransaction
    public let verifyData: IAPVerifyData

    public init(transaction: IAPVerifiedTransaction, verifyData: IAPVerifyData) {
        self.transaction = transaction
        self.verifyData = verifyData
    }
}
