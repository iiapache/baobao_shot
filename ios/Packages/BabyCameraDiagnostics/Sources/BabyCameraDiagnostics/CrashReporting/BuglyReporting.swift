import Foundation

/// Bugly 崩溃采集门面：按编译条件路由至 Live 或 Stub。
public enum BuglyReporting {
    public static func bootstrap(configuration: CrashReportingConfiguration) {
        CrashReportingBackendSelector.buglyBackend().bootstrap(configuration: configuration)
    }

    public static func captureSmokeTestError(message: String = "T7.7 iOS bugly smoke test") {
        CrashReportingBackendSelector.buglyBackend().captureSmokeTestError(message: message)
    }
}

