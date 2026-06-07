import Foundation

/// 网络中断时持久化待上送收据，启动后由 IAPService 续传。
public protocol PendingIAPReceiptStoring: Sendable {
    func loadAll() -> [IAPVerifiedTransaction]
    func save(_ transaction: IAPVerifiedTransaction)
    func remove(transactionID: String)
}

public final class PendingIAPReceiptStore: PendingIAPReceiptStoring, @unchecked Sendable {
    public static let storageKey = "com.babycamera.credit.pendingIAPReceipts"

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, key: String = PendingIAPReceiptStore.storageKey) {
        self.defaults = defaults
        self.key = key
    }

    public func loadAll() -> [IAPVerifiedTransaction] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([IAPVerifiedTransaction].self, from: data)) ?? []
    }

    public func save(_ transaction: IAPVerifiedTransaction) {
        lock.lock()
        defer { lock.unlock() }
        var items = loadAllUnlocked()
        if let index = items.firstIndex(where: { $0.transactionID == transaction.transactionID }) {
            items[index] = transaction
        } else {
            items.append(transaction)
        }
        persistUnlocked(items)
    }

    public func remove(transactionID: String) {
        lock.lock()
        defer { lock.unlock() }
        let items = loadAllUnlocked().filter { $0.transactionID != transactionID }
        persistUnlocked(items)
    }

    private func loadAllUnlocked() -> [IAPVerifiedTransaction] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([IAPVerifiedTransaction].self, from: data)) ?? []
    }

    private func persistUnlocked(_ items: [IAPVerifiedTransaction]) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}
