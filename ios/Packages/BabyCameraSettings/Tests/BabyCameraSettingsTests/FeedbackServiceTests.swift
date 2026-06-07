import BabyCameraNetwork
import DesignSystem
import XCTest
@testable import BabyCameraSettings

final class FeedbackLogRedactorTests: XCTestCase {
    func testRedactsAccessAndRefreshTokens() {
        let raw = #"{"accessToken":"secret-access","refreshToken":"secret-refresh"}"#
        let redacted = FeedbackLogRedactor.redact(raw)

        XCTAssertFalse(redacted.contains("secret-access"))
        XCTAssertFalse(redacted.contains("secret-refresh"))
        XCTAssertTrue(redacted.contains(#""accessToken":"***""#))
        XCTAssertTrue(redacted.contains(#""refreshToken":"***""#))
    }

    func testRedactsPhoneAndAppleSub() {
        let raw = #"phone 13800138000 {"phone":"13800138000","appleSub":"000123.abc456def789.1234"}"#
        let redacted = FeedbackLogRedactor.redact(raw)

        XCTAssertFalse(redacted.contains("13800138000"))
        XCTAssertFalse(redacted.contains("000123.abc456def789.1234"))
        XCTAssertTrue(redacted.contains(#""phone":"***""#))
        XCTAssertTrue(redacted.contains(#""appleSub":"***""#))
    }

    func testRedactsBearerAuthorizationHeader() {
        let raw = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.secret"
        let redacted = FeedbackLogRedactor.redact(raw)

        XCTAssertFalse(redacted.contains("eyJhbGciOiJIUzI1NiJ9.secret"))
        XCTAssertTrue(redacted.contains("Bearer ***"))
    }
}

final class FeedbackServiceTests: XCTestCase {
    private let versionInfo = AppVersionInfo(marketingVersion: "1.2.3", buildNumber: "45")

    func testValidateRejectsEmptyDescription() {
        let service = makeService()
        let result = service.validate(
            submission: FeedbackSubmission(category: .bug, description: "   \n  ")
        )
        XCTAssertEqual(result, .emptyDescription)
    }

    func testValidateRejectsDescriptionTooLong() {
        let service = makeService()
        let longText = String(repeating: "a", count: FeedbackService.maxDescriptionLength + 1)
        let result = service.validate(
            submission: FeedbackSubmission(category: .suggestion, description: longText)
        )
        XCTAssertEqual(result, .descriptionTooLong(maxLength: FeedbackService.maxDescriptionLength))
    }

    func testCategoryMapsToMailSubject() {
        let service = makeService()

        XCTAssertEqual(service.makeSubject(for: .featureIssue), L10n.string("settings.feedback.mail.subject", "功能问题"))
        XCTAssertEqual(service.makeSubject(for: .bug), L10n.string("settings.feedback.mail.subject", "BUG"))
        XCTAssertEqual(service.makeSubject(for: .suggestion), L10n.string("settings.feedback.mail.subject", "建议"))
        XCTAssertEqual(service.makeSubject(for: .other), L10n.string("settings.feedback.mail.subject", "其他"))
    }

    func testMailBodyContainsCategoryDescriptionAndVersion() {
        let service = makeService(logLines: ["[GET] /v1/me status=200"])
        let submission = FeedbackSubmission(category: .bug, description: "无法上传照片")
        let draft = service.makeMailDraft(submission: submission)

        XCTAssertEqual(draft.recipient, "ops@babycamera.app")
        XCTAssertEqual(draft.subject, L10n.string("settings.feedback.mail.subject", "BUG"))
        XCTAssertTrue(draft.body.contains(L10n.string("settings.feedback.mail.category", "BUG")))
        XCTAssertTrue(draft.body.contains(L10n.string("settings.feedback.mail.description_header")))
        XCTAssertTrue(draft.body.contains("无法上传照片"))
        XCTAssertTrue(draft.body.contains(L10n.string("settings.feedback.mail.app_version", "1.2.3 (45)")))
        XCTAssertTrue(draft.body.contains(L10n.string("settings.feedback.mail.user_id", "usr_feedback")))
        XCTAssertTrue(draft.body.contains(L10n.string("settings.feedback.mail.log_header")))
    }

    func testDiagnosticAttachmentRedactsSensitiveTokens() {
        let sensitiveLine = """
        [POST] /v1/auth/login status=200 body={"accessToken":"tok_abc","refreshToken":"tok_def","phone":"13912345678","appleSub":"000111.aaaa.bbbb"}
        """
        let service = makeService(logLines: [sensitiveLine])
        let draft = service.makeMailDraft(
            submission: FeedbackSubmission(category: .other, description: "测试")
        )

        let attachmentText = String(data: draft.attachmentData, encoding: .utf8) ?? ""
        XCTAssertFalse(attachmentText.contains("tok_abc"))
        XCTAssertFalse(attachmentText.contains("tok_def"))
        XCTAssertFalse(attachmentText.contains("13912345678"))
        XCTAssertFalse(attachmentText.contains("000111.aaaa.bbbb"))
        XCTAssertTrue(attachmentText.contains("***"))
    }

    func testMailtoURLUsesRecipientSubjectAndBody() throws {
        let service = makeService(mailComposerAvailable: false)
        let draft = service.makeMailDraft(
            submission: FeedbackSubmission(category: .featureIssue, description: "按钮无响应")
        )

        let url = try XCTUnwrap(service.makeMailtoURL(draft: draft))
        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertEqual(url.path, "ops@babycamera.app")
        XCTAssertTrue(url.absoluteString.contains("subject="))
        XCTAssertTrue(url.absoluteString.contains("body="))
    }

    func testSupportEmailResolverPrefersComplianceThenDefaults() {
        let compliance = ComplianceConfig(supportEmail: "support@example.com")
        XCTAssertEqual(
            FeedbackSupportEmailResolver.resolve(compliance: compliance),
            "support@example.com"
        )
        XCTAssertEqual(
            FeedbackSupportEmailResolver.resolve(compliance: ComplianceConfig(supportEmail: "{{SUPPORT_EMAIL}}")),
            FeedbackSupportEmailResolver.defaultEmail
        )
        XCTAssertEqual(
            FeedbackSupportEmailResolver.resolve(),
            FeedbackSupportEmailResolver.defaultEmail
        )
    }

    private func makeService(
        logLines: [String] = [],
        mailComposerAvailable: Bool = true
    ) -> FeedbackService {
        FeedbackService(
            supportEmail: "ops@babycamera.app",
            versionInfo: versionInfo,
            userId: "usr_feedback",
            logProvider: MockFeedbackLogProvider(lines: logLines),
            mailComposerAvailability: { mailComposerAvailable }
        )
    }
}

@MainActor
final class FeedbackViewModelTests: XCTestCase {
    func testSubmitShowsValidationMessageForEmptyDescription() {
        let viewModel = FeedbackViewModel(service: MockFeedbackService())
        viewModel.description = "  "

        viewModel.submit()

        XCTAssertEqual(viewModel.validationMessage, L10n.string("settings.feedback.validation.empty"))
        XCTAssertFalse(viewModel.isMailComposerPresented)
    }
}

private struct MockFeedbackLogProvider: FeedbackLogProviding {
    let lines: [String]

    func recentLines(limit: Int) -> [String] {
        Array(lines.suffix(limit))
    }
}

private struct MockFeedbackService: FeedbackServing {
    func validate(submission: FeedbackSubmission) -> FeedbackValidationResult {
        let trimmed = submission.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .emptyDescription : .valid
    }

    func makeMailDraft(submission: FeedbackSubmission) -> FeedbackMailDraft {
        FeedbackMailDraft(
            recipient: "ops@babycamera.app",
            subject: "test",
            body: submission.description,
            attachmentData: Data(),
            attachmentFilename: "diagnostic-log.json"
        )
    }

    func canUseNativeMailComposer() -> Bool { true }

    func makeMailtoURL(draft: FeedbackMailDraft) -> URL? {
        URL(string: "mailto:\(draft.recipient)")
    }
}
