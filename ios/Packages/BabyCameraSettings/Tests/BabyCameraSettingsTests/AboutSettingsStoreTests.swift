import XCTest
@testable import BabyCameraSettings

@MainActor
final class AboutSettingsStoreTests: XCTestCase {
    func testDisplayTextUsesPendingWhenICPMissing() async {
        let store = AboutSettingsStore(
            complianceService: MockComplianceService(config: ComplianceConfig.defaults(for: .cn)),
            versionInfo: AppVersionInfo(marketingVersion: "1.2.3", buildNumber: "99")
        )

        await store.load()

        XCTAssertEqual(store.icpDisplayText, ComplianceConfig.icpPendingText)
        XCTAssertEqual(store.algorithmFilingDisplayText, ComplianceConfig.algorithmPendingText)
    }

    func testDisplayTextShowsRemoteValues() async {
        let remote = ComplianceConfig(
            icpNumber: "京ICP备12345678号-9A",
            algorithmFilingSummary: "Seedream 备案号"
        )
        let store = AboutSettingsStore(
            complianceService: MockComplianceService(config: remote),
            versionInfo: .placeholder
        )

        await store.load()

        XCTAssertEqual(store.icpDisplayText, "京ICP备12345678号-9A")
        XCTAssertEqual(store.algorithmFilingDisplayText, "Seedream 备案号")
    }

    func testLoadSurfacesServiceError() async {
        let store = AboutSettingsStore(
            complianceService: MockComplianceService(error: TestError.sample),
            versionInfo: .placeholder
        )

        await store.load()

        XCTAssertNotNil(store.errorMessage)
    }
}

private enum TestError: Error {
    case sample
}

private struct MockComplianceService: ComplianceConfigServing {
    let config: ComplianceConfig?
    let error: Error?

    init(config: ComplianceConfig) {
        self.config = config
        self.error = nil
    }

    init(error: Error) {
        self.config = nil
        self.error = error
    }

    func fetchComplianceConfig() async throws -> ComplianceConfig {
        if let error {
            throw error
        }
        return config ?? ComplianceConfig.defaults(for: .cn)
    }
}
