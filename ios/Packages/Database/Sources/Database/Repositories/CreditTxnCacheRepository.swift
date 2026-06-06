import Foundation

public struct CreditTxnCacheRecord: Sendable, Equatable {
    public var id: String
    public var type: String
    public var amount: Int
    public var ref: String?
    public var createdAt: Int64

    public init(id: String, type: String, amount: Int, ref: String? = nil, createdAt: Int64) {
        self.id = id
        self.type = type
        self.amount = amount
        self.ref = ref
        self.createdAt = createdAt
    }
}

/// Local cache for credit transactions (server-authoritative; read-only sync in T4.x).
public protocol CreditTxnCacheRepository: Sendable {
    func fetchRecent(limit: Int) async throws -> [CreditTxnCacheRecord]
    func save(_ txn: CreditTxnCacheRecord) async throws
    func deleteAll() async throws
}
