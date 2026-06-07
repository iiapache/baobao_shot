#if canImport(Sentry)
import Foundation
import Sentry

enum SentryReportingLive: CrashReportingBackend {
    static func bootstrap(configuration: CrashReportingConfiguration) {
        guard configuration.hasSentryDSN, let dsn = configuration.sentryDSN else { return }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = configuration.environment
            options.releaseName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            options.tracesSampleRate = 0.1
            options.enableAutoSessionTracking = true
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            options.beforeSend = { event in
                event.user?.email = nil
                return event
            }
        }
    }

    static func captureSmokeTestError(message: String) {
        SentrySDK.capture(
            error: NSError(
                domain: "app.babycamera",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        )
    }
}
#endif
