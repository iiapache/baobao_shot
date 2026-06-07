import Foundation

/// 里程碑本地通知 identifier 规范，保证去重与按宝宝批量清理。
public enum MilestoneNotificationIdentifier {
    public static let prefix = "milestone"
    public static let category = "MILESTONE"

    public static func make(babyId: String, milestoneId: String, yearSuffix: Int? = nil) -> String {
        if let yearSuffix {
            return "\(prefix).\(babyId).\(milestoneId).\(yearSuffix)"
        }
        return "\(prefix).\(babyId).\(milestoneId)"
    }

    public static func babyPrefix(babyId: String) -> String {
        "\(prefix).\(babyId)."
    }

    public static func isMilestoneNotification(_ identifier: String) -> Bool {
        identifier.hasPrefix("\(prefix).")
    }
}
