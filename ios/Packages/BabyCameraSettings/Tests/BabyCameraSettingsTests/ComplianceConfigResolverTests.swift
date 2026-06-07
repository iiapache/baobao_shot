import BabyCameraNetwork
import XCTest
@testable import BabyCameraSettings

final class ComplianceConfigResolverTests: XCTestCase {
    func testResolveUsesRemoteICPNumber() {
        let features: [String: FeatureFlagResult] = [
            ComplianceConfigResolver.icpNumberKey: FeatureFlagResult(
                enabled: true,
                variant: "京ICP备12345678号-9A"
            ),
        ]

        let config = ComplianceConfigResolver.resolve(features: features, region: .cn)

        XCTAssertEqual(config.icpNumber, "京ICP备12345678号-9A")
    }

    func testResolveIgnoresTemplatePlaceholderICP() {
        let features: [String: FeatureFlagResult] = [
            ComplianceConfigResolver.icpNumberKey: FeatureFlagResult(
                enabled: true,
                variant: "{{ICP_NUMBER}}"
            ),
        ]

        let config = ComplianceConfigResolver.resolve(features: features, region: .cn)

        XCTAssertEqual(config.icpNumber, ComplianceConfig.defaults(for: .cn).icpNumber)
    }

    func testResolveAlgorithmFilingSummary() {
        let features: [String: FeatureFlagResult] = [
            ComplianceConfigResolver.algorithmFilingSummaryKey: FeatureFlagResult(
                enabled: true,
                variant: "Seedream：网信算备 11000000000001 号"
            ),
        ]

        let config = ComplianceConfigResolver.resolve(features: features, region: .cn)

        XCTAssertEqual(config.algorithmFilingSummary, "Seedream：网信算备 11000000000001 号")
    }

    func testResolvePolicyURLsFromRemoteConfig() {
        let features: [String: FeatureFlagResult] = [
            ComplianceConfigResolver.privacyPolicyURLKey: FeatureFlagResult(
                enabled: true,
                variant: "https://policy.example.com/privacy-cn.html"
            ),
            ComplianceConfigResolver.termsURLKey: FeatureFlagResult(
                enabled: true,
                variant: "https://policy.example.com/terms-cn.html"
            ),
            ComplianceConfigResolver.deepSynthesisURLKey: FeatureFlagResult(
                enabled: true,
                variant: "https://policy.example.com/deep-synthesis-cn.html"
            ),
            ComplianceConfigResolver.thirdPartySDKListURLKey: FeatureFlagResult(
                enabled: true,
                variant: "https://policy.example.com/third-party-sdk.html"
            ),
        ]

        let config = ComplianceConfigResolver.resolve(features: features, region: .cn)

        XCTAssertEqual(config.privacyPolicyURL?.absoluteString, "https://policy.example.com/privacy-cn.html")
        XCTAssertEqual(config.termsURL?.absoluteString, "https://policy.example.com/terms-cn.html")
        XCTAssertEqual(config.deepSynthesisURL?.absoluteString, "https://policy.example.com/deep-synthesis-cn.html")
        XCTAssertEqual(config.thirdPartySDKListURL?.absoluteString, "https://policy.example.com/third-party-sdk.html")
    }

    func testResolvePrivacyPolicyVersionCN() {
        let features: [String: FeatureFlagResult] = [
            ComplianceConfigResolver.privacyPolicyVersionCNKey: FeatureFlagResult(
                enabled: true,
                variant: "v1.2.0"
            ),
        ]

        let config = ComplianceConfigResolver.resolve(features: features, region: .cn)

        XCTAssertEqual(config.privacyPolicyVersion, "v1.2.0")
    }

    func testResolvePrivacyPolicyVersionOSUsesOSKey() {
        let features: [String: FeatureFlagResult] = [
            ComplianceConfigResolver.privacyPolicyVersionCNKey: FeatureFlagResult(
                enabled: true,
                variant: "v9.9.9"
            ),
            ComplianceConfigResolver.privacyPolicyVersionOSKey: FeatureFlagResult(
                enabled: true,
                variant: "v2.0.0"
            ),
        ]

        let config = ComplianceConfigResolver.resolve(features: features, region: .os)

        XCTAssertEqual(config.privacyPolicyVersion, "v2.0.0")
    }

    func testResolveAllPolicyVersionsFromRemoteConfig() {
        let features: [String: FeatureFlagResult] = [
            ComplianceConfigResolver.privacyPolicyVersionCNKey: FeatureFlagResult(
                enabled: true,
                variant: "v1.1.0"
            ),
            ComplianceConfigResolver.termsVersionKey: FeatureFlagResult(
                enabled: true,
                variant: "v1.3.0"
            ),
            ComplianceConfigResolver.deepSynthesisVersionKey: FeatureFlagResult(
                enabled: true,
                variant: "v1.4.0"
            ),
            ComplianceConfigResolver.thirdPartySDKListVersionKey: FeatureFlagResult(
                enabled: true,
                variant: "v1.5.0"
            ),
        ]

        let config = ComplianceConfigResolver.resolve(features: features, region: .cn)

        XCTAssertEqual(config.privacyPolicyVersion, "v1.1.0")
        XCTAssertEqual(config.termsVersion, "v1.3.0")
        XCTAssertEqual(config.deepSynthesisVersion, "v1.4.0")
        XCTAssertEqual(config.thirdPartySDKListVersion, "v1.5.0")
    }

    func testResolvePolicyVersionsFallBackToDefaults() {
        let config = ComplianceConfigResolver.resolve(features: [:], region: .cn)

        XCTAssertEqual(config.privacyPolicyVersion, ComplianceConfig.defaultPolicyVersion)
        XCTAssertEqual(config.termsVersion, ComplianceConfig.defaultPolicyVersion)
        XCTAssertEqual(config.deepSynthesisVersion, ComplianceConfig.defaultPolicyVersion)
        XCTAssertEqual(config.thirdPartySDKListVersion, ComplianceConfig.defaultPolicyVersion)
    }

    func testResolveFallsBackToRegionDefaults() {
        let config = ComplianceConfigResolver.resolve(features: [:], region: .cn)
        let defaults = ComplianceConfig.defaults(for: .cn)

        XCTAssertEqual(config.icpNumber, defaults.icpNumber)
        XCTAssertEqual(config.algorithmFilingSummary, defaults.algorithmFilingSummary)
        XCTAssertEqual(config.icpQueryURL?.absoluteString, "https://beian.miit.gov.cn/")
        XCTAssertEqual(
            config.privacyPolicyURL?.absoluteString,
            "https://www.babycamera.app/legal/privacy-policy-cn"
        )
        XCTAssertEqual(
            config.thirdPartySDKListURL?.absoluteString,
            "https://www.babycamera.app/legal/third-party-sdk-list"
        )
    }

    func testResolveOSRegionUsesPrivacyOSURLKey() {
        let features: [String: FeatureFlagResult] = [
            ComplianceConfigResolver.privacyPolicyURLKey: FeatureFlagResult(
                enabled: true,
                variant: "https://policy.example.com/privacy-cn.html"
            ),
            ComplianceConfigResolver.privacyPolicyOSURLKey: FeatureFlagResult(
                enabled: true,
                variant: "https://policy.example.com/privacy-os.html"
            ),
        ]

        let config = ComplianceConfigResolver.resolve(features: features, region: .os)

        XCTAssertEqual(config.privacyPolicyURL?.absoluteString, "https://policy.example.com/privacy-os.html")
    }

    func testResolveSupportEmailFromRemoteConfig() {
        let features: [String: FeatureFlagResult] = [
            ComplianceConfigResolver.supportEmailKey: FeatureFlagResult(
                enabled: true,
                variant: "support@babycamera.app"
            ),
        ]

        let config = ComplianceConfigResolver.resolve(features: features, region: .cn)

        XCTAssertEqual(config.supportEmail, "support@babycamera.app")
    }

    func testDefaultsUsesExplicitLegalBaseURL() {
        let config = ComplianceConfig.defaults(
            for: .cn,
            legalBaseURL: ComplianceConfig.debugLegalBaseURL
        )

        XCTAssertEqual(
            config.termsURL?.absoluteString,
            "http://localhost:8765/compliance/legal/terms-of-service"
        )
        XCTAssertEqual(
            config.privacyPolicyURL?.absoluteString,
            "http://localhost:8765/compliance/legal/privacy-policy-cn"
        )
        XCTAssertEqual(
            config.deepSynthesisURL?.absoluteString,
            "http://localhost:8765/compliance/legal/deep-synthesis-notice"
        )
    }

    func testLegalBaseURLReadsFromInfoDictionary() {
        let resolved = ComplianceConfig.legalBaseURL(from: [
            "LegalBaseURL": "http://localhost:8765/compliance/legal",
        ])
        XCTAssertEqual(resolved, "http://localhost:8765/compliance/legal")
    }

    func testResolveIgnoresDisabledFlags() {
        let features: [String: FeatureFlagResult] = [
            ComplianceConfigResolver.icpNumberKey: FeatureFlagResult(
                enabled: false,
                variant: "京ICP备12345678号-9A"
            ),
            ComplianceConfigResolver.termsVersionKey: FeatureFlagResult(
                enabled: false,
                variant: "v9.0.0"
            ),
        ]

        let config = ComplianceConfigResolver.resolve(features: features, region: .cn)

        XCTAssertEqual(config.icpNumber, ComplianceConfig.defaults(for: .cn).icpNumber)
        XCTAssertEqual(config.termsVersion, ComplianceConfig.defaultPolicyVersion)
    }
}
