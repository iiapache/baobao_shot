import Foundation

public enum UninstallReminderIdentifier {
    public static let prefix = "uninstallReminder"
    public static let category = "UNINSTALL_REMINDER"

    public static func globalIdentifier() -> String {
        "\(prefix).global"
    }

    public static func isUninstallReminder(_ identifier: String) -> Bool {
        identifier.hasPrefix("\(prefix).")
    }
}
