import Foundation

/// Sentry SDK 占位：无 `import Sentry`，不阻塞编译；DSN 就绪后可替换为真实 SDK。
public enum SentryReportingStub {
    public static func bootstrap(configuration: CrashReportingConfiguration) {
        guard configuration.hasSentryDSN, let dsn = configuration.sentryDSN else { return }

        #if DEBUG
        print(
            "[CrashReporting] Sentry stub armed",
            "environment=\(configuration.environment)",
            "dsnSuffix=\(Self.maskedSuffix(dsn))"
        )
        #endif

        // 真实接入：import Sentry → SentrySDK.start { options in ... }
        // 见 Packages/BabyCameraDiagnostics/Documentation/SENTRY_SPM.md
        _ = dsn
    }

    /// T0.8 / T7.7 smoke test 占位；接入 SDK 后改为 `SentrySDK.capture(error:)`.
    public static func captureSmokeTestError(message: String = "T7.7 iOS sentry smoke test") {
        #if DEBUG
        print("[CrashReporting] Sentry smoke (stub): \(message)")
        #endif
    }

    private static func maskedSuffix(_ dsn: String) -> String {
        guard dsn.count > 8 else { return "***" }
        return "…" + dsn.suffix(8)
    }
}
