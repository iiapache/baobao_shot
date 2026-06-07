import Foundation

public protocol OnboardingProgressStoring: Sendable {
    func hasCompleted(userId: String) -> Bool
    func markCompleted(userId: String)
    func reset(userId: String)
}

public struct UserDefaultsOnboardingProgressStore: OnboardingProgressStoring, Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "com.babycamera.onboarding.completed") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func hasCompleted(userId: String) -> Bool {
        defaults.bool(forKey: storageKey(for: userId))
    }

    public func markCompleted(userId: String) {
        defaults.set(true, forKey: storageKey(for: userId))
    }

    public func reset(userId: String) {
        defaults.removeObject(forKey: storageKey(for: userId))
    }

    private func storageKey(for userId: String) -> String {
        "\(keyPrefix).\(userId)"
    }
}
