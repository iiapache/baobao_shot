#if canImport(Bugly)
import Bugly
import Foundation

enum BuglyReportingLive: CrashReportingBackend {
    static func bootstrap(configuration: CrashReportingConfiguration) {
        guard configuration.hasBuglyAppID, let appID = configuration.buglyAppID else { return }

        let config = BuglyConfig()
        config.debugMode = false
        config.channel = configuration.environment
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            config.version = version
        }
        Bugly.start(withAppId: appID, config: config)
    }

    static func captureSmokeTestError(message: String) {
        let exception = NSException(
            name: NSExceptionName(rawValue: "BabyCameraSmokeTest"),
            reason: message,
            userInfo: nil
        )
        Bugly.report(exception)
    }
}
#endif
