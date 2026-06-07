import BabyCameraBaby
import DesignSystem
import SwiftUI

struct OnboardingBabyStepView: View {
    @Binding var name: String
    @Binding var birthDate: Date
    @Binding var gender: BabyGender?

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            onboardingStepIntro(
                icon: "figure.and.child.holdinghands",
                title: L10n.string("onboarding.baby.title"),
                subtitle: L10n.string("onboarding.baby.subtitle")
            )

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(L10n.localizedKey("onboarding.baby.name_label"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                TextField(L10n.string("common.required"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboardingBabyNameField")
            }

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(L10n.localizedKey("onboarding.baby.birth_date_label"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                DatePicker(
                    L10n.string("onboarding.baby.birth_date_label"),
                    selection: $birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(L10n.localizedKey("onboarding.baby.gender_label"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                HStack(spacing: DSSpacing.sm) {
                    genderChip(.male, label: L10n.string("onboarding.baby.gender.male"))
                    genderChip(.female, label: L10n.string("onboarding.baby.gender.female"))
                    genderChip(nil, label: L10n.string("onboarding.baby.gender.skip"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func genderChip(_ value: BabyGender?, label: String) -> some View {
        let isSelected = gender == value
        return Button {
            gender = value
        } label: {
            Text(label)
                .font(DSTypography.caption)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
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
