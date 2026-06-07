import DesignSystem
import SwiftUI

struct SettingsInfoRow: View {
    let title: String
    let value: String
    let accessibilityIdentifier: String
    var action: (() -> Void)?

    var body: some View {
        DSListRow(
            title: title,
            subtitle: value,
            showsDivider: true,
            action: action
        ) {
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textTertiary)
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
