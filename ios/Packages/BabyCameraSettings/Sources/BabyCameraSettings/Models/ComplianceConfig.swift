import BabyCameraNetwork
import DesignSystem
import Foundation

/// 合规远端配置（config-svc feature flags，T6.10 / T7.2 compliance 文档）。
public struct ComplianceConfig: Equatable, Sendable {
    public let icpNumber: String?
    public let icpQueryURL: URL?
    public let algorithmFilingSummary: String?
    public let privacyPolicyURL: URL?
    public let termsURL: URL?
    public let deepSynthesisURL: URL?
    public let thirdPartySDKListURL: URL?
    public let privacyPolicyVersion: String?
    public let termsVersion: String?
    public let deepSynthesisVersion: String?
    public let thirdPartySDKListVersion: String?
    public let supportEmail: String?

    public init(
        icpNumber: String? = nil,
        icpQueryURL: URL? = nil,
        algorithmFilingSummary: String? = nil,
        privacyPolicyURL: URL? = nil,
        termsURL: URL? = nil,
        deepSynthesisURL: URL? = nil,
        thirdPartySDKListURL: URL? = nil,
        privacyPolicyVersion: String? = nil,
        termsVersion: String? = nil,
        deepSynthesisVersion: String? = nil,
        thirdPartySDKListVersion: String? = nil,
        supportEmail: String? = nil
    ) {
        self.icpNumber = icpNumber
        self.icpQueryURL = icpQueryURL
        self.algorithmFilingSummary = algorithmFilingSummary
        self.privacyPolicyURL = privacyPolicyURL
        self.termsURL = termsURL
        self.deepSynthesisURL = deepSynthesisURL
        self.thirdPartySDKListURL = thirdPartySDKListURL
        self.privacyPolicyVersion = privacyPolicyVersion
        self.termsVersion = termsVersion
        self.deepSynthesisVersion = deepSynthesisVersion
        self.thirdPartySDKListVersion = thirdPartySDKListVersion
        self.supportEmail = supportEmail
    }

    /// 未获正式备案号前的占位文案。
    public static var icpPendingText: String { L10n.string("settings.compliance.pending") }
    public static var algorithmPendingText: String { L10n.string("settings.compliance.pending") }
    public static let policyHost = "www.babycamera.app"
    public static let defaultPolicyVersion = "v1.0.0"

    public static func defaults(for region: AppRegion) -> ComplianceConfig {
        let base = "https://\(policyHost)/legal"
        let privacySlug = region == .cn ? "privacy-policy-cn" : "privacy-policy-os"
        return ComplianceConfig(
            icpQueryURL: URL(string: "https://beian.miit.gov.cn/"),
            privacyPolicyURL: URL(string: "\(base)/\(privacySlug)"),
            termsURL: URL(string: "\(base)/terms-of-service"),
            deepSynthesisURL: URL(string: "\(base)/deep-synthesis-notice"),
            thirdPartySDKListURL: URL(string: "\(base)/third-party-sdk-list"),
            privacyPolicyVersion: defaultPolicyVersion,
            termsVersion: defaultPolicyVersion,
            deepSynthesisVersion: defaultPolicyVersion,
            thirdPartySDKListVersion: defaultPolicyVersion
        )
    }

    /// 政策行副标题：`v1.0.0 · 在浏览器中查看`
    public static func legalLinkSubtitle(version: String?) -> String {
        let resolved = version?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let resolved, !resolved.isEmpty {
            return L10n.string("settings.compliance.version_in_browser", resolved)
        }
        return L10n.string("settings.compliance.view_in_browser")
    }
}
