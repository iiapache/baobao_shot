import DesignSystem
import SwiftUI

public struct FeedbackFormView: View {
    @ObservedObject private var viewModel: FeedbackViewModel
    @Environment(\.openURL) private var openURL

    public init(viewModel: FeedbackViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                Text(L10n.localizedKey("settings.feedback.description"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(L10n.string("settings.feedback.category_section")) {
                Picker(L10n.string("settings.feedback.category_picker"), selection: $viewModel.category) {
                    ForEach(FeedbackCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("feedbackCategoryPicker")
            }

            Section(L10n.string("settings.feedback.description_section")) {
                TextEditor(text: $viewModel.description)
                    .frame(minHeight: 140)
                    .font(DSTypography.body)
                    .accessibilityIdentifier("feedbackDescriptionEditor")

                HStack {
                    if let validationMessage = viewModel.validationMessage {
                        Text(validationMessage)
                            .font(DSTypography.caption)
                            .foregroundStyle(DSColors.error)
                    }
                    Spacer()
                    Text(viewModel.characterCountText)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)
                }
            }

            Section(L10n.string("settings.feedback.attachment_section")) {
                Toggle(L10n.string("settings.feedback.screenshot_placeholder"), isOn: $viewModel.screenshotAttached)
                    .disabled(true)
                    .foregroundStyle(DSColors.textSecondary)
                    .accessibilityIdentifier("feedbackScreenshotPlaceholder")
            }

            Section {
                DSButton(L10n.string("settings.feedback.submit"), style: .primary, systemImage: "envelope.fill", isDisabled: !viewModel.canSubmit) {
                    viewModel.submit()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("feedbackSubmitButton")
            }
        }
        .navigationTitle(L10n.string("settings.feedback.title"))
        .accessibilityIdentifier("feedbackFormView")
        #if canImport(MessageUI)
        .sheet(isPresented: $viewModel.isMailComposerPresented) {
            if let draft = viewModel.mailDraft {
                MailComposeView(draft: draft) {
                    viewModel.dismissMailComposer()
                }
            }
        }
        #endif
        .onChange(of: viewModel.mailtoURL) { url in
            guard let url else { return }
            openURL(url)
            viewModel.mailtoURL = nil
        }
    }
}
