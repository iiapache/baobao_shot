import DesignSystem
import SwiftUI

public struct AboutSettingsView: View {
    @ObservedObject private var store: AboutSettingsStore
    private let feedbackViewModel: FeedbackViewModel?
    @State private var presentedURL: URL?

    public init(store: AboutSettingsStore, feedbackViewModel: FeedbackViewModel? = nil) {
        self.store = store
        self.feedbackViewModel = feedbackViewModel
    }

    public var body: some View {
        aboutContent
            .navigationTitle(L10n.string("settings.about.title"))
            .overlay {
                if store.isLoading {
                    DSLoadingView(message: L10n.string("settings.about.loading"))
                        .background(DSColors.background.opacity(0.9))
                }
            }
            .task {
                await store.load()
            }
            .sheet(item: $presentedURL) { url in
                SafariView(url: url)
            }
    }

    private var aboutContent: some View {
        VStack(spacing: 0) {
            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DSSpacing.listRowHorizontalPadding)
                    .padding(.vertical, DSSpacing.xs)
            }

            SettingsInfoRow(
                title: L10n.string("settings.about.version"),
                value: store.versionInfo.displayString,
                accessibilityIdentifier: "aboutVersionRow"
            )

            legalLinkRow(
                title: L10n.string("settings.about.terms"),
                icon: "doc.text",
                url: store.compliance.termsURL,
                version: store.compliance.termsVersion,
                accessibilityIdentifier: "aboutTermsLink"
            )

            legalLinkRow(
                title: L10n.string("settings.about.privacy_policy"),
                icon: "hand.raised.fill",
                url: store.compliance.privacyPolicyURL,
                version: store.compliance.privacyPolicyVersion,
                accessibilityIdentifier: "aboutPrivacyPolicyLink"
            )

            legalLinkRow(
                title: L10n.string("settings.about.deep_synthesis"),
                icon: "sparkles.rectangle.stack",
                url: store.compliance.deepSynthesisURL,
                version: store.compliance.deepSynthesisVersion,
                accessibilityIdentifier: "aboutDeepSynthesisLink"
            )

            legalLinkRow(
                title: L10n.string("settings.about.third_party_sdk"),
                icon: "list.bullet.rectangle",
                url: store.compliance.thirdPartySDKListURL,
                version: store.compliance.thirdPartySDKListVersion,
                accessibilityIdentifier: "aboutThirdPartySDKLink"
            )

            SettingsInfoRow(
                title: L10n.string("settings.about.icp"),
                value: store.icpDisplayText,
                accessibilityIdentifier: "aboutICPRow",
                action: store.compliance.icpQueryURL.map { queryURL in
                    { presentedURL = queryURL }
                }
            )

            SettingsInfoRow(
                title: L10n.string("settings.about.algorithm_filing"),
                value: store.algorithmFilingDisplayText,
                accessibilityIdentifier: "aboutAlgorithmFilingRow"
            )

            if let feedbackViewModel {
                NavigationLink {
                    FeedbackFormView(viewModel: feedbackViewModel)
                } label: {
                    DSListRow(
                        icon: "envelope.fill",
                        title: L10n.string("settings.about.contact_support"),
                        subtitle: L10n.string("settings.about.contact_support.subtitle"),
                        showsDivider: false
                    ) {
                        Image(systemName: "chevron.right")
                            .font(DSTypography.caption)
                            .foregroundStyle(DSColors.textTertiary)
                    }
                }
                .accessibilityIdentifier("aboutContactSupportLink")
            }
        }
        .background(DSColors.surface)
    }

    private func legalLinkRow(
        title: String,
        icon: String,
        url: URL?,
        version: String?,
        accessibilityIdentifier: String
    ) -> some View {
        DSListRow(
            icon: icon,
            title: title,
            subtitle: ComplianceConfig.legalLinkSubtitle(version: version),
            showsDivider: true,
            action: url.map { link in { presentedURL = link } }
        ) {
            Image(systemName: "chevron.right")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textTertiary)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
