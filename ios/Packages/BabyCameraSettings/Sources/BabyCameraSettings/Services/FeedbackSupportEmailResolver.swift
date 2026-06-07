import Foundation

/// 运营客服邮箱解析：ComplianceConfig → Info.plist → 默认值。
public enum FeedbackSupportEmailResolver {
    public static let defaultEmail = "support@babycamera.app"
    public static let infoPlistKey = "SupportEmail"

    public static func resolve(
        compliance: ComplianceConfig? = nil,
        bundle: Bundle = .main
    ) -> String {
        if let email = compliance?.supportEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
           !email.isEmpty,
           !ComplianceConfigResolver.isTemplatePlaceholder(email) {
            return email
        }

        if let plistEmail = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String {
            let trimmed = plistEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !ComplianceConfigResolver.isTemplatePlaceholder(trimmed) {
                return trimmed
            }
        }

        return defaultEmail
    }
}
