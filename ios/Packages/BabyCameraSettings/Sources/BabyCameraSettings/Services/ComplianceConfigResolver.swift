import BabyCameraNetwork
import Foundation

/// 从 config-svc feature flags 解析合规配置。
public enum ComplianceConfigResolver {
    public static let icpNumberKey = "compliance.icp_number"
    public static let icpQueryURLKey = "compliance.icp_query_url"
    public static let algorithmFilingSummaryKey = "compliance.algorithm_filing_summary"
    public static let privacyPolicyURLKey = "compliance.policy_urls.privacy_cn"
    public static let privacyPolicyOSURLKey = "compliance.policy_urls.privacy_os"
    public static let termsURLKey = "compliance.policy_urls.terms_cn"
    public static let deepSynthesisURLKey = "compliance.policy_urls.deep_synthesis_cn"
    public static let thirdPartySDKListURLKey = "compliance.policy_urls.third_party_sdk"
    public static let privacyPolicyVersionCNKey = "compliance.policy_versions.privacy_cn"
    public static let privacyPolicyVersionOSKey = "compliance.policy_versions.privacy_os"
    public static let termsVersionKey = "compliance.policy_versions.terms"
    public static let deepSynthesisVersionKey = "compliance.policy_versions.deep_synthesis"
    public static let thirdPartySDKListVersionKey = "compliance.policy_versions.third_party_sdk"
    public static let supportEmailKey = "compliance.support_email"

    public static func resolve(
        features: [String: FeatureFlagResult],
        region: AppRegion
    ) -> ComplianceConfig {
        let defaults = ComplianceConfig.defaults(for: region)
        let privacyURLKey = region == .cn ? privacyPolicyURLKey : privacyPolicyOSURLKey
        let privacyVersionKey = region == .cn ? privacyPolicyVersionCNKey : privacyPolicyVersionOSKey

        return ComplianceConfig(
            icpNumber: resolvedText(features[icpNumberKey]),
            icpQueryURL: resolvedURL(features[icpQueryURLKey]) ?? defaults.icpQueryURL,
            algorithmFilingSummary: resolvedText(features[algorithmFilingSummaryKey]),
            privacyPolicyURL: resolvedURL(features[privacyURLKey]) ?? defaults.privacyPolicyURL,
            termsURL: resolvedURL(features[termsURLKey]) ?? defaults.termsURL,
            deepSynthesisURL: resolvedURL(features[deepSynthesisURLKey]) ?? defaults.deepSynthesisURL,
            thirdPartySDKListURL: resolvedURL(features[thirdPartySDKListURLKey]) ?? defaults.thirdPartySDKListURL,
            privacyPolicyVersion: resolvedText(features[privacyVersionKey]) ?? defaults.privacyPolicyVersion,
            termsVersion: resolvedText(features[termsVersionKey]) ?? defaults.termsVersion,
            deepSynthesisVersion: resolvedText(features[deepSynthesisVersionKey]) ?? defaults.deepSynthesisVersion,
            thirdPartySDKListVersion: resolvedText(features[thirdPartySDKListVersionKey]) ?? defaults.thirdPartySDKListVersion,
            supportEmail: resolvedText(features[supportEmailKey])
        )
    }

    static func resolvedText(_ flag: FeatureFlagResult?) -> String? {
        guard let flag, flag.enabled else { return nil }
        guard let variant = flag.variant?.trimmingCharacters(in: .whitespacesAndNewlines),
              !variant.isEmpty,
              !isTemplatePlaceholder(variant) else {
            return nil
        }
        return variant
    }

    static func resolvedURL(_ flag: FeatureFlagResult?) -> URL? {
        guard let text = resolvedText(flag) else { return nil }
        return URL(string: text)
    }

    static func isTemplatePlaceholder(_ value: String) -> Bool {
        value.contains("{{") && value.contains("}}")
    }
}
