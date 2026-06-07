import DesignSystem
import Foundation

public enum OnboardingStep: Int, CaseIterable, Sendable, Identifiable {
    case profile
    case family
    case baby
    case consent
    case backup

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .profile: L10n.string("onboarding.step.profile")
        case .family: L10n.string("onboarding.step.family")
        case .baby: L10n.string("onboarding.step.baby")
        case .consent: L10n.string("onboarding.step.consent")
        case .backup: L10n.string("onboarding.step.backup")
        }
    }

    public var stepIndex: Int { rawValue + 1 }

    public static let totalSteps = allCases.count
}

public enum OnboardingFamilyPath: String, CaseIterable, Sendable, Identifiable {
    case create
    case join

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .create: L10n.string("onboarding.family_path.create")
        case .join: L10n.string("onboarding.family_path.join")
        }
    }
}
