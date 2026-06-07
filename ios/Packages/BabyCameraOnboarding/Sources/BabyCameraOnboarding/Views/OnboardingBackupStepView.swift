import DesignSystem
import SwiftUI

struct OnboardingBackupStepView: View {
    @Binding var acknowledged: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            onboardingStepIntro(
                icon: "icloud.and.arrow.up.fill",
                title: L10n.string("onboarding.backup.title"),
                subtitle: L10n.string("onboarding.backup.subtitle")
            )

            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    backupRow(
                        icon: "iphone",
                        title: L10n.string("onboarding.backup.local.title"),
                        detail: L10n.string("onboarding.backup.local.detail")
                    )
                    backupRow(
                        icon: "externaldrive.fill.badge.icloud",
                        title: L10n.string("onboarding.backup.cloud.title"),
                        detail: L10n.string("onboarding.backup.cloud.detail")
                    )
                    backupRow(
                        icon: "exclamationmark.triangle.fill",
                        title: L10n.string("onboarding.backup.uninstall.title"),
                        detail: L10n.string("onboarding.backup.uninstall.detail")
                    )
                }
            }

            Toggle(isOn: $acknowledged) {
                Text(L10n.localizedKey("onboarding.backup.acknowledge"))
                    .font(DSTypography.subheadline)
                    .foregroundStyle(DSColors.textPrimary)
            }
            .tint(DSColors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func backupRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(DSColors.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(title)
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(DSColors.textPrimary)
                Text(detail)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
            }
        }
    }
}
