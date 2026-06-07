import DesignSystem
import SwiftUI

struct OnboardingFamilyStepView: View {
    @Binding var familyPath: OnboardingFamilyPath
    @Binding var familyName: String
    @Binding var inviteCode: String
    let onScanTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            onboardingStepIntro(
                icon: "house.fill",
                title: L10n.string("onboarding.family.title"),
                subtitle: L10n.string("onboarding.family.subtitle")
            )

            Picker(L10n.string("onboarding.family.mode_picker"), selection: $familyPath) {
                ForEach(OnboardingFamilyPath.allCases) { path in
                    Text(path.title).tag(path)
                }
            }
            .pickerStyle(.segmented)

            switch familyPath {
            case .create:
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(L10n.localizedKey("onboarding.family.name_label"))
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)
                    TextField(L10n.string("onboarding.family.name_placeholder"), text: $familyName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("onboardingFamilyNameField")
                }
            case .join:
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    TextField(L10n.string("onboarding.family.invite_placeholder"), text: $inviteCode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)

                    DSButton(L10n.string("onboarding.family.scan_join"), style: .secondary, systemImage: "qrcode.viewfinder") {
                        onScanTapped()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
