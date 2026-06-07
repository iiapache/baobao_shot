import BabyCameraFamily
import DesignSystem
import SwiftUI

struct OnboardingProfileStepView: View {
    @Binding var nickname: String
    @Binding var selectedRelation: FamilyRelation

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            onboardingStepIntro(
                icon: "person.crop.circle.badge.plus",
                title: L10n.string("onboarding.profile.title"),
                subtitle: L10n.string("onboarding.profile.subtitle")
            )

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(L10n.localizedKey("onboarding.profile.nickname_label"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                TextField(L10n.string("onboarding.profile.nickname_placeholder"), text: $nickname)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.nickname)
                    .accessibilityIdentifier("onboardingNicknameField")
            }

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(L10n.localizedKey("onboarding.profile.relation_label"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 100), spacing: DSSpacing.sm)],
                    spacing: DSSpacing.sm
                ) {
                    ForEach(FamilyRelation.allCases) { relation in
                        relationChip(relation)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relationChip(_ relation: FamilyRelation) -> some View {
        let isSelected = selectedRelation == relation
        return Button {
            selectedRelation = relation
        } label: {
            Text(relation.displayName)
                .font(DSTypography.caption)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .frame(maxWidth: .infinity)
                .background(isSelected ? DSColors.primaryMuted : DSColors.surface)
                .foregroundStyle(isSelected ? DSColors.primary : DSColors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius)
                        .stroke(isSelected ? DSColors.primary : DSColors.separator, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
