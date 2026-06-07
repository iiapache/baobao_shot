import Foundation

public enum DailyPhotoReminderIdentifier {
    public static let prefix = "dailyPhoto"
    public static let category = "DAILY_PHOTO"

    public static func make(babyId: String) -> String {
        "\(prefix).\(babyId)"
    }

    public static func globalIdentifier() -> String {
        "\(prefix).global"
    }

    public static func isDailyPhotoReminder(_ identifier: String) -> Bool {
        identifier.hasPrefix("\(prefix).")
    }
}
