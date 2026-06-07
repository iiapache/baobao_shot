import Foundation

/// Bugly SDK 占位：无腾讯 SDK 依赖，不阻塞编译；AppID 就绪后可替换为 `Bugly.start(withAppId:)`.
public enum BuglyReportingStub {
    public static func bootstrap(configuration: CrashReportingConfiguration) {
        guard configuration.hasBuglyAppID, let appID = configuration.buglyAppID else { return }

        #if DEBUG
        print(
            "[CrashReporting] Bugly stub armed",
            "environment=\(configuration.environment)",
            "appIDSuffix=\(Self.maskedSuffix(appID))"
        )
        #endif

        // 真实接入：import Bugly → Bugly.start(withAppId:appID, ...)
        _ = appID
    }

    /// TestFlight / staging 手动触发测试崩溃（接入 SDK 后调用 Bugly 测试接口）。
    public static func captureSmokeTestError(message: String = "T7.7 iOS bugly smoke test") {
        #if DEBUG
        print("[CrashReporting] Bugly smoke (stub): \(message)")
        #endif
    }

    private static func maskedSuffix(_ value: String) -> String {
        guard value.count > 4 else { return "***" }
        return "…" + value.suffix(4)
    }
}
