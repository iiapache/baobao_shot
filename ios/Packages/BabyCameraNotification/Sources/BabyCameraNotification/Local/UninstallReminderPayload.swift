import Foundation

/// 卸载提醒本地通知 deep link 载荷（点击通知跳转备份管理）。
public struct UninstallReminderPayload: Sendable, Equatable {
    public static let deepLinkScheme = "baobao"
    public static let deepLinkHost = "settings"
    public static let deepLinkPath = "/backup"

    public static let sourceKey = "source"
    public static let routeKey = "route"
    public static let deepLinkKey = "deepLink"

    public static let source = "uninstallReminder"
    public static let route = "backup"

    public var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = Self.deepLinkScheme
        components.host = Self.deepLinkHost
        components.path = Self.deepLinkPath
        return components.url
    }

    public static func userInfo() -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = [
            sourceKey: source,
            routeKey: route,
        ]
        if let deepLink = UninstallReminderPayload().deepLinkURL?.absoluteString {
            info[deepLinkKey] = deepLink
        }
        return info
    }

    public static func from(userInfo: [AnyHashable: Any]) -> UninstallReminderPayload? {
        guard userInfo[sourceKey] as? String == source,
              userInfo[routeKey] as? String == route else {
            return nil
        }
        return UninstallReminderPayload()
    }
}
