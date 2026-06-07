import Foundation

public protocol SubscriptionEntitlementCaching: Sendable {
    func load() -> SubscriptionSnapshot?
    func save(_ snapshot: SubscriptionSnapshot)
    func clear()
    func isValid(_ snapshot: SubscriptionSnapshot, now: Date) -> Bool
}

/// 本地权益缓存，TTL 与后端 `cacheTtlSeconds` 对齐（默认 10 分钟）。
public struct SubscriptionEntitlementCache: SubscriptionEntitlementCaching {
    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "com.babycamera.subscription.entitlements"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public func load() -> SubscriptionSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? decoder.decode(SubscriptionSnapshot.self, from: data)
    }

    public func save(_ snapshot: SubscriptionSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public func clear() {
        defaults.removeObject(forKey: storageKey)
    }

    public func isValid(_ snapshot: SubscriptionSnapshot, now: Date = Date()) -> Bool {
        let ttl = TimeInterval(max(snapshot.cacheTtlSeconds, 1))
        return now.timeIntervalSince(snapshot.fetchedAt) < ttl
    }
}
