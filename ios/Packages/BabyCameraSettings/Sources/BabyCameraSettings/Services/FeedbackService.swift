import BabyCameraNetwork
import DesignSystem
import Foundation
#if canImport(MessageUI)
import MessageUI
#endif

public struct FeedbackSubmission: Equatable, Sendable {
    public let category: FeedbackCategory
    public let description: String
    public let screenshotAttached: Bool

    public init(
        category: FeedbackCategory,
        description: String,
        screenshotAttached: Bool = false
    ) {
        self.category = category
        self.description = description
        self.screenshotAttached = screenshotAttached
    }
}

public enum FeedbackValidationResult: Equatable, Sendable {
    case valid
    case emptyDescription
    case descriptionTooLong(maxLength: Int)
}

public struct FeedbackMailDraft: Equatable, Sendable {
    public let recipient: String
    public let subject: String
    public let body: String
    public let attachmentData: Data
    public let attachmentFilename: String
    public let attachmentMIMEType: String

    public init(
        recipient: String,
        subject: String,
        body: String,
        attachmentData: Data,
        attachmentFilename: String,
        attachmentMIMEType: String = "application/json"
    ) {
        self.recipient = recipient
        self.subject = subject
        self.body = body
        self.attachmentData = attachmentData
        self.attachmentFilename = attachmentFilename
        self.attachmentMIMEType = attachmentMIMEType
    }
}

public protocol FeedbackLogProviding: Sendable {
    func recentLines(limit: Int) -> [String]
}

public struct FeedbackDiagnosticLogProvider: FeedbackLogProviding {
    private let lineLimit: Int

    public init(lineLimit: Int = 100) {
        self.lineLimit = lineLimit
    }

    public func recentLines(limit: Int) -> [String] {
        FeedbackDiagnosticLogStore.recentLines(limit: min(limit, lineLimit))
    }
}

public protocol FeedbackServing: Sendable {
    func validate(submission: FeedbackSubmission) -> FeedbackValidationResult
    func makeMailDraft(submission: FeedbackSubmission) -> FeedbackMailDraft
    func canUseNativeMailComposer() -> Bool
    func makeMailtoURL(draft: FeedbackMailDraft) -> URL?
}

public struct FeedbackService: FeedbackServing {
    public static let maxDescriptionLength = 1000
    public static let diagnosticLogLineLimit = 100

    private let supportEmail: String
    private let versionInfo: AppVersionInfo
    private let userId: String
    private let logProvider: any FeedbackLogProviding
    private let mailComposerAvailability: @Sendable () -> Bool

    public init(
        supportEmail: String,
        versionInfo: AppVersionInfo,
        userId: String,
        logProvider: any FeedbackLogProviding = FeedbackDiagnosticLogProvider(),
        mailComposerAvailability: @escaping @Sendable () -> Bool = FeedbackService.defaultMailComposerAvailability
    ) {
        self.supportEmail = supportEmail
        self.versionInfo = versionInfo
        self.userId = userId
        self.logProvider = logProvider
        self.mailComposerAvailability = mailComposerAvailability
    }

    public func validate(submission: FeedbackSubmission) -> FeedbackValidationResult {
        let trimmed = submission.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .emptyDescription
        }
        if submission.description.count > Self.maxDescriptionLength {
            return .descriptionTooLong(maxLength: Self.maxDescriptionLength)
        }
        return .valid
    }

    public func makeMailDraft(submission: FeedbackSubmission) -> FeedbackMailDraft {
        let trimmedDescription = submission.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let diagnosticJSON = makeDiagnosticLogJSON()
        let attachmentData = Data(diagnosticJSON.utf8)

        let body = makeEmailBody(
            submission: submission,
            trimmedDescription: trimmedDescription,
            diagnosticJSON: diagnosticJSON
        )

        return FeedbackMailDraft(
            recipient: supportEmail,
            subject: makeSubject(for: submission.category),
            body: body,
            attachmentData: attachmentData,
            attachmentFilename: "diagnostic-log.json"
        )
    }

    public func canUseNativeMailComposer() -> Bool {
        mailComposerAvailability()
    }

    public func makeMailtoURL(draft: FeedbackMailDraft) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = draft.recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: draft.subject),
            URLQueryItem(name: "body", value: draft.body),
        ]
        return components.url
    }

    // MARK: - Internal builders (testable)

    func makeSubject(for category: FeedbackCategory) -> String {
        L10n.string("settings.feedback.mail.subject", category.mailSubjectPrefix)
    }

    func makeEmailBody(
        submission: FeedbackSubmission,
        trimmedDescription: String,
        diagnosticJSON: String
    ) -> String {
        let screenshotLine = submission.screenshotAttached
            ? L10n.string("settings.feedback.mail.screenshot_attached")
            : L10n.string("settings.feedback.mail.screenshot_none")
        var lines = [
            L10n.string("settings.feedback.mail.category", submission.category.displayName),
            L10n.string("settings.feedback.mail.user_id", userId),
            L10n.string("settings.feedback.mail.app_version", versionInfo.displayString),
            screenshotLine,
            "",
            L10n.string("settings.feedback.mail.description_header"),
            trimmedDescription,
            "",
            L10n.string("settings.feedback.mail.log_header"),
            diagnosticJSON,
        ]
        return lines.joined(separator: "\n")
    }

    func makeDiagnosticLogJSON() -> String {
        let rawLines = logProvider.recentLines(limit: Self.diagnosticLogLineLimit)
        let redactedLines = rawLines.map { FeedbackLogRedactor.redact($0) }
        let payload = DiagnosticLogPayload(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            appVersion: versionInfo.displayString,
            userId: userId,
            lineCount: redactedLines.count,
            lines: redactedLines
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"lines":[],"error":"encode_failed"}"#
        }
        return FeedbackLogRedactor.redact(json)
    }

    private static func defaultMailComposerAvailability() -> Bool {
        #if canImport(MessageUI)
        return MFMailComposeViewController.canSendMail()
        #else
        return false
        #endif
    }
}

private struct DiagnosticLogPayload: Encodable {
    let generatedAt: String
    let appVersion: String
    let userId: String
    let lineCount: Int
    let lines: [String]
}
