import Foundation

/// 卸载提醒偏好（design-ios §12.2：设置 → 数据 → 卸载提醒）。
public struct UninstallReminderPreferences: Sendable, Equatable, Codable {
    public var enabled: Bool

    public init(enabled: Bool = false) {
        self.enabled = enabled
    }
}

public protocol UninstallReminderPreferencesStoring: Sendable {
    func load() -> UninstallReminderPreferences
    func save(_ preferences: UninstallReminderPreferences)
}

public final class UserDefaultsUninstallReminderStore: UninstallReminderPreferencesStoring, @unchecked Sendable {
    public static let storageKey = "com.babycamera.notification.uninstallReminder"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = storageKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> UninstallReminderPreferences {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(UninstallReminderPreferences.self, from: data) else {
            return UninstallReminderPreferences()
        }
        return decoded
    }

    public func save(_ preferences: UninstallReminderPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}
