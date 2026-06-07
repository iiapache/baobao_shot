import Foundation

/// 从 Info.plist 读取崩溃监控配置（T7.7：Bugly + Sentry 双采集骨架）。
public struct CrashReportingConfiguration: Sendable, Equatable {
    public let sentryDSN: String?
    public let buglyAppID: String?
    public let environment: String
    public let isEnabled: Bool

    public init(bundle: Bundle = .main) {
        self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) {
        let rawDSN = infoDictionary["SentryDSN"] as? String
        sentryDSN = rawDSN?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : rawDSN

        let rawBugly = infoDictionary["BuglyAppID"] as? String
        buglyAppID = rawBugly?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : rawBugly

        environment = (infoDictionary["AppEnvironment"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (infoDictionary["AppEnvironment"] as! String)
            : "dev"

        isEnabled = Self.parseBool(infoDictionary["CrashReportingEnabled"])
    }

    public var hasSentryDSN: Bool { sentryDSN != nil }
    public var hasBuglyAppID: Bool { buglyAppID != nil }

    private static func parseBool(_ value: Any?) -> Bool {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "yes" || normalized == "true" || normalized == "1"
        default:
            return false
        }
    }
}
