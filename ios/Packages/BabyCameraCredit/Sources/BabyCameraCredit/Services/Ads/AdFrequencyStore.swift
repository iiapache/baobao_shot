import Foundation

public struct AdFrequencyLimits: Sendable, Equatable {
    public let splashPerDay: Int
    public let interstitialPerDay: Int

    public static let `default` = AdFrequencyLimits(splashPerDay: 1, interstitialPerDay: 3)

    public init(splashPerDay: Int, interstitialPerDay: Int) {
        self.splashPerDay = max(0, splashPerDay)
        self.interstitialPerDay = max(0, interstitialPerDay)
    }

    public func limit(for placement: AdPlacement) -> Int? {
        switch placement {
        case .splash:
            return splashPerDay
        case .interstitial:
            return interstitialPerDay
        case .rewarded:
            return nil
        }
    }
}

public protocol AdFrequencyStoring: Sendable {
    func impressionCount(for placement: AdPlacement, on day: Date) -> Int
    func recordImpression(for placement: AdPlacement, on day: Date)
    func reset()
}

/// 本地频次计数（开屏 1/天，插页 ≤3/天）。
public final class AdFrequencyStore: AdFrequencyStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let keyPrefix: String
    private let lock = NSLock()

    public init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        keyPrefix: String = "com.babycamera.ad.freq"
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.keyPrefix = keyPrefix
    }

    public func impressionCount(for placement: AdPlacement, on day: Date) -> Int {
        lock.withLock {
            defaults.integer(forKey: storageKey(placement: placement, day: day))
        }
    }

    public func recordImpression(for placement: AdPlacement, on day: Date) {
        lock.withLock {
            let key = storageKey(placement: placement, day: day)
            let next = defaults.integer(forKey: key) + 1
            defaults.set(next, forKey: key)
        }
    }

    public func reset() {
        lock.withLock {
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private func storageKey(placement: AdPlacement, day: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let y = components.year ?? 0
        let m = components.month ?? 0
        let d = components.day ?? 0
        return "\(keyPrefix).\(placement.rawValue).\(y)-\(m)-\(d)"
    }
}

/// 内存实现，供单测注入。
public final class InMemoryAdFrequencyStore: AdFrequencyStoring, @unchecked Sendable {
    private var counts: [String: Int] = [:]
    private let calendar: Calendar
    private let lock = NSLock()

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func impressionCount(for placement: AdPlacement, on day: Date) -> Int {
        lock.withLock { counts[key(placement: placement, day: day)] ?? 0 }
    }

    public func recordImpression(for placement: AdPlacement, on day: Date) {
        lock.withLock {
            let storageKey = key(placement: placement, day: day)
            counts[storageKey, default: 0] += 1
        }
    }

    public func reset() {
        lock.withLock { counts.removeAll() }
    }

    private func key(placement: AdPlacement, day: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(placement.rawValue)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

public struct AdFrequencyGate: Sendable {
    private let store: AdFrequencyStoring
    private let limits: AdFrequencyLimits
    private let now: @Sendable () -> Date

    public init(
        store: AdFrequencyStoring,
        limits: AdFrequencyLimits = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.limits = limits
        self.now = now
    }

    public func canShow(_ placement: AdPlacement) -> Bool {
        guard let limit = limits.limit(for: placement) else { return true }
        return store.impressionCount(for: placement, on: now()) < limit
    }

    public func recordShown(_ placement: AdPlacement) {
        guard limits.limit(for: placement) != nil else { return }
        store.recordImpression(for: placement, on: now())
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
