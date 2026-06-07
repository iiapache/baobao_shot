import Foundation

/// Sentry SDK 占位：无 `import Sentry` 时不阻塞编译；CI 与 Debug 默认走此路径。
enum SentryNoopBackend: CrashReportingBackend {
    static func bootstrap(configuration: CrashReportingConfiguration) {
        guard configuration.hasSentryDSN, let dsn = configuration.sentryDSN else { return }

        #if DEBUG
        print(
            "[CrashReporting] Sentry stub armed",
            "environment=\(configuration.environment)",
            "dsnSuffix=\(Self.maskedSuffix(dsn))"
        )
        #endif

        _ = dsn
    }

    static func captureSmokeTestError(message: String) {
        #if DEBUG
        print("[CrashReporting] Sentry smoke (stub): \(message)")
        #endif
    }

    private static func maskedSuffix(_ dsn: String) -> String {
        guard dsn.count > 8 else { return "***" }
        return "…" + dsn.suffix(8)
    }
}
