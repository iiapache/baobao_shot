import Foundation

/// 崩溃上报后端契约；Stub 供 CI/无 SDK 编译，Live 在 `canImport` 且非 Debug 时启用。
public protocol CrashReportingBackend: Sendable {
    static func bootstrap(configuration: CrashReportingConfiguration)
    static func captureSmokeTestError(message: String)
}

enum CrashReportingBackendSelector {
    static func sentryBackend() -> CrashReportingBackend.Type {
        #if DEBUG
        return SentryNoopBackend.self
        #elseif canImport(Sentry)
        return SentryReportingLive.self
        #else
        return SentryNoopBackend.self
        #endif
    }

    static func buglyBackend() -> CrashReportingBackend.Type {
        #if DEBUG
        return BuglyNoopBackend.self
        #elseif canImport(Bugly)
        return BuglyReportingLive.self
        #else
        return BuglyNoopBackend.self
        #endif
    }
}
