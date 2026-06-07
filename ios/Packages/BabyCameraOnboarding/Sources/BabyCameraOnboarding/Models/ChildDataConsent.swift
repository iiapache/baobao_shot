import BabyCameraNetwork
import DesignSystem
import Foundation

/// 与 auth-family-svc consent.CurrentConsentVersion 保持一致
public enum ChildDataConsent {
    public static let currentVersion = "child_consent_v1"

    public static var policySummary: String {
        L10n.string("onboarding.consent.policy_summary")
    }

    public static func hasServerConsent(in profile: UserProfile?) -> Bool {
        profile?.consents?.childData == true
    }

    public static func hasValidConsent(in profile: UserProfile?) -> Bool {
        hasServerConsent(in: profile)
    }

    public static func hasValidConsent(userId: String?, profile: UserProfile?) -> Bool {
        ConsentVersionChecker.hasValidConsent(userId: userId, profile: profile)
    }
}

public enum RestrictedFeature: Sendable, CaseIterable, Identifiable {
    case camera
    case photoImport
    case babyCreate
    case familyCreate
    case feedPublish
    case feedEngagement
    case aiSubmit

    public var id: Self { self }

    public var restrictionMessage: String {
        switch self {
        case .camera:
            L10n.string("onboarding.consent.restricted.camera")
        case .photoImport:
            L10n.string("onboarding.consent.restricted.import")
        case .babyCreate:
            L10n.string("onboarding.consent.restricted.baby")
        case .familyCreate:
            L10n.string("onboarding.consent.restricted.family")
        case .feedPublish:
            L10n.string("onboarding.consent.restricted.feed_publish")
        case .feedEngagement:
            L10n.string("onboarding.consent.restricted.feed_engagement")
        case .aiSubmit:
            L10n.string("onboarding.consent.restricted.ai_submit")
        }
    }
}

public enum ChildDataConsentGate {
    public static func isFeatureAllowed(
        _ feature: RestrictedFeature,
        profile: UserProfile?,
        userId: String? = nil
    ) -> Bool {
        switch feature {
        case .camera, .photoImport, .babyCreate, .familyCreate,
             .feedPublish, .feedEngagement, .aiSubmit:
            if let userId {
                return ConsentVersionChecker.hasValidConsent(userId: userId, profile: profile)
            }
            return ChildDataConsent.hasValidConsent(in: profile)
        }
    }

    public static func requiresConsent(for error: APIError) -> Bool {
        error.code == .accountConsentRequired
    }

    public static func requiresReconsent(userId: String?, profile: UserProfile?) -> Bool {
        ConsentVersionChecker.requiresReconsent(userId: userId, profile: profile)
    }
}
