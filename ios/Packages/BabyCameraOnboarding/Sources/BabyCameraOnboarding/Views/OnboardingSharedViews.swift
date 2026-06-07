import DesignSystem
import SwiftUI

func onboardingStepIntro(icon: String, title: String, subtitle: String) -> some View {
    VStack(spacing: DSSpacing.sm) {
        Image(systemName: icon)
            .font(.system(size: 40))
            .foregroundStyle(DSColors.primary)
        Text(title)
            .font(DSTypography.title3)
            .foregroundStyle(DSColors.textPrimary)
            .multilineTextAlignment(.center)
        Text(subtitle)
            .font(DSTypography.subheadline)
            .foregroundStyle(DSColors.textSecondary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
}
