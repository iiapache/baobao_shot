import DesignSystem
import SwiftUI

struct OnboardingConsentStepView: View {
    @Binding var consentAccepted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            onboardingStepIntro(
                icon: "doc.text.fill",
                title: L10n.string("onboarding.consent.title"),
                subtitle: L10n.string("onboarding.consent.subtitle")
            )

            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text(L10n.string("onboarding.consent.document_title", ChildDataConsent.currentVersion))
                        .font(DSTypography.bodyEmphasis)
                        .foregroundStyle(DSColors.textPrimary)

                    Text(ChildDataConsent.policySummary)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(isOn: $consentAccepted) {
                Text(L10n.localizedKey("onboarding.consent.toggle"))
                    .font(DSTypography.subheadline)
                    .foregroundStyle(DSColors.textPrimary)
            }
            .tint(DSColors.primary)
            .accessibilityIdentifier("onboardingConsentToggle")

            Text(L10n.localizedKey("onboarding.consent.restricted_hint"))
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.warning)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
