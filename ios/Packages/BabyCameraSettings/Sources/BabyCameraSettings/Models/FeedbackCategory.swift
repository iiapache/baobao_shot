import DesignSystem
import Foundation

/// 客服反馈类别（T6.13）。
public enum FeedbackCategory: String, CaseIterable, Identifiable, Sendable {
    case featureIssue = "feature_issue"
    case bug = "bug"
    case suggestion = "suggestion"
    case other = "other"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .featureIssue:
            return L10n.string("settings.feedback.category.feature")
        case .bug:
            return L10n.string("settings.feedback.category.bug")
        case .suggestion:
            return L10n.string("settings.feedback.category.suggestion")
        case .other:
            return L10n.string("settings.feedback.category.other")
        }
    }

    public var mailSubjectPrefix: String {
        displayName
    }
}
