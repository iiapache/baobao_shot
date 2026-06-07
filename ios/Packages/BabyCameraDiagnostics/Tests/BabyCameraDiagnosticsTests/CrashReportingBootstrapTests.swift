@testable import BabyCameraDiagnostics
import XCTest

final class CrashReportingBootstrapTests: XCTestCase {
    func testConfigureIfNeededDoesNotCrash() {
        CrashReportingBootstrap.configureIfNeeded(bundle: .main)
    }

    func testSentryReportingSmokeDoesNotCrash() {
        SentryReporting.captureSmokeTestError(message: "unit-test")
        SentryReportingStub.captureSmokeTestError(message: "unit-test-compat")
    }

    func testBuglyReportingSmokeDoesNotCrash() {
        BuglyReporting.captureSmokeTestError(message: "unit-test")
        BuglyReportingStub.captureSmokeTestError(message: "unit-test-compat")
    }

    func testDisabledConfigurationSkipsBootstrap() {
        let config = CrashReportingConfiguration(infoDictionary: [
            "CrashReportingEnabled": false,
            "SentryDSN": "https://example@sentry.io/1",
        ])
        XCTAssertFalse(config.isEnabled)
    }
}
