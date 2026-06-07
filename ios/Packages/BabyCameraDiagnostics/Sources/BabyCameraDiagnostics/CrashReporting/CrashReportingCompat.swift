import Foundation

/// QA 模板兼容入口（`CRASH_MEMORY_SIZE_REPORT_TEMPLATE.md`）。
public enum SentryReportingStub {
    public static func bootstrap(configuration: CrashReportingConfiguration) {
        SentryReporting.bootstrap(configuration: configuration)
    }

    public static func captureSmokeTestError(message: String = "T7.7 iOS sentry smoke test") {
        SentryReporting.captureSmokeTestError(message: message)
    }
}

/// QA 模板兼容入口。
public enum BuglyReportingStub {
    public static func bootstrap(configuration: CrashReportingConfiguration) {
        BuglyReporting.bootstrap(configuration: configuration)
    }

    public static func captureSmokeTestError(message: String = "T7.7 iOS bugly smoke test") {
        BuglyReporting.captureSmokeTestError(message: message)
    }
}
