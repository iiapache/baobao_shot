import Foundation

/// Bugly SDK 占位：无腾讯 SDK 依赖时不阻塞编译；CI 与 Debug 默认走此路径。
enum BuglyNoopBackend: CrashReportingBackend {
    static func bootstrap(configuration: CrashReportingConfiguration) {
        guard configuration.hasBuglyAppID, let appID = configuration.buglyAppID else { return }

        #if DEBUG
        print(
            "[CrashReporting] Bugly stub armed",
            "environment=\(configuration.environment)",
            "appIDSuffix=\(Self.maskedSuffix(appID))"
        )
        #endif

        _ = appID
    }

    static func captureSmokeTestError(message: String) {
        #if DEBUG
        print("[CrashReporting] Bugly smoke (stub): \(message)")
        #endif
    }

    private static func maskedSuffix(_ value: String) -> String {
        guard value.count > 4 else { return "***" }
        return "…" + value.suffix(4)
    }
}
