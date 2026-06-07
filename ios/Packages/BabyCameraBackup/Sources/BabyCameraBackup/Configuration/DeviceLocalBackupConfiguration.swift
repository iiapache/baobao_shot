import Foundation

/// iCloud / 系统相册备份运行模式：stub（Debug / UI 测试）或 live（真机 PhotoKit + CloudKit）。
public enum DeviceLocalBackupMode: String, Sendable, Equatable {
    case stub
    case live
}

public enum DeviceLocalBackupConfiguration {
    public static let useLiveICloudInfoPlistKey = "UseLiveICloudBackup"
    public static let useLivePhotosInfoPlistKey = "UseLivePhotosBackup"
    public static let iCloudContainerInfoPlistKey = "ICloudBackupContainerIdentifier"

    public static let defaultICloudContainerIdentifier = "iCloud.app.babycamera"

    public static func useLiveICloudFromInfoPlist(bundle: Bundle = .main) -> Bool {
        parseBool(bundle.infoDictionary?[useLiveICloudInfoPlistKey] as? String, defaultValue: false)
    }

    public static func useLivePhotosFromInfoPlist(bundle: Bundle = .main) -> Bool {
        parseBool(bundle.infoDictionary?[useLivePhotosInfoPlistKey] as? String, defaultValue: false)
    }

    public static func iCloudContainerIdentifierFromInfoPlist(bundle: Bundle = .main) -> String {
        parseNonEmpty(bundle.infoDictionary?[iCloudContainerInfoPlistKey] as? String)
            ?? defaultICloudContainerIdentifier
    }

    public static func resolveICloudMode(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useLiveOverride: Bool? = nil
    ) -> DeviceLocalBackupMode {
        if forceStub { return .stub }
        let wantsLive = useLiveOverride ?? useLiveICloudFromInfoPlist(bundle: bundle)
        return wantsLive ? .live : .stub
    }

    public static func resolvePhotosMode(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useLiveOverride: Bool? = nil
    ) -> DeviceLocalBackupMode {
        if forceStub { return .stub }
        let wantsLive = useLiveOverride ?? useLivePhotosFromInfoPlist(bundle: bundle)
        return wantsLive ? .live : .stub
    }

    private static func parseBool(_ raw: String?, defaultValue: Bool) -> Bool {
        guard let raw else { return defaultValue }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized.hasPrefix("$(") {
            return defaultValue
        }
        switch normalized {
        case "yes", "1", "true":
            return true
        case "no", "0", "false":
            return false
        default:
            return defaultValue
        }
    }

    private static func parseNonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") {
            return nil
        }
        return trimmed
    }
}
