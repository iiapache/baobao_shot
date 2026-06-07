import DesignSystem
import Foundation

@MainActor
public final class FeedbackViewModel: ObservableObject {
    @Published public var category: FeedbackCategory = .bug
    @Published public var description: String = ""
    @Published public var screenshotAttached = false
    @Published public private(set) var validationMessage: String?
    @Published public var isMailComposerPresented = false
    @Published public private(set) var mailDraft: FeedbackMailDraft?
    @Published public var mailtoURL: URL?

    public let service: any FeedbackServing

    public init(service: any FeedbackServing) {
        self.service = service
    }

    public var characterCountText: String {
        "\(description.count)/\(FeedbackService.maxDescriptionLength)"
    }

    public var canSubmit: Bool {
        service.validate(currentSubmission) == .valid
    }

    public func submit() {
        validationMessage = nil
        let submission = currentSubmission

        switch service.validate(submission) {
        case .valid:
            break
        case .emptyDescription:
            validationMessage = L10n.string("settings.feedback.validation.empty")
            return
        case .descriptionTooLong(let maxLength):
            validationMessage = L10n.string("settings.feedback.validation.too_long", maxLength)
            return
        }

        let draft = service.makeMailDraft(submission: submission)

        if service.canUseNativeMailComposer() {
            mailDraft = draft
            isMailComposerPresented = true
        } else if let url = service.makeMailtoURL(draft: draft) {
            mailtoURL = url
        } else {
            validationMessage = L10n.string("settings.feedback.validation.mail_unavailable")
        }
    }

    public func dismissMailComposer() {
        isMailComposerPresented = false
        mailDraft = nil
    }

    private var currentSubmission: FeedbackSubmission {
        FeedbackSubmission(
            category: category,
            description: description,
            screenshotAttached: screenshotAttached
        )
    }
}
