import Foundation

/// Sentry 崩溃采集门面：按编译条件路由至 Live 或 Stub。
public enum SentryReporting {
    public static func bootstrap(configuration: CrashReportingConfiguration) {
        CrashReportingBackendSelector.sentryBackend().bootstrap(configuration: configuration)
    }

    public static func captureSmokeTestError(message: String = "T7.7 iOS sentry smoke test") {
        CrashReportingBackendSelector.sentryBackend().captureSmokeTestError(message: message)
    }
}

