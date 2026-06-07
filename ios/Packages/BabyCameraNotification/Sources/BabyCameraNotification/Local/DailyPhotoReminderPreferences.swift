import Foundation

/// 每日拍照提醒偏好（PRD §4.12：默认关闭，可自定义时间）。
public struct DailyPhotoReminderPreferences: Sendable, Equatable, Codable {
    public static let defaultHour = 20
    public static let defaultMinute = 0

    public var enabled: Bool
    public var hour: Int
    public var minute: Int
    public var babyId: String?
    public var babyName: String?

    public init(
        enabled: Bool = false,
        hour: Int = Self.defaultHour,
        minute: Int = Self.defaultMinute,
        babyId: String? = nil,
        babyName: String? = nil
    ) {
        self.enabled = enabled
        self.hour = hour
        self.minute = minute
        self.babyId = babyId
        self.babyName = babyName
    }

    public var normalizedHour: Int {
        max(0, min(23, hour))
    }

    public var normalizedMinute: Int {
        max(0, min(59, minute))
    }
}

public protocol DailyPhotoReminderPreferencesStoring: Sendable {
    func load() -> DailyPhotoReminderPreferences
    func save(_ preferences: DailyPhotoReminderPreferences)
}

public final class UserDefaultsDailyPhotoReminderStore: DailyPhotoReminderPreferencesStoring, @unchecked Sendable {
    public static let storageKey = "com.babycamera.notification.dailyPhotoReminder"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = storageKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> DailyPhotoReminderPreferences {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(DailyPhotoReminderPreferences.self, from: data) else {
            return DailyPhotoReminderPreferences()
        }
        return decoded
    }

    public func save(_ preferences: DailyPhotoReminderPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}
