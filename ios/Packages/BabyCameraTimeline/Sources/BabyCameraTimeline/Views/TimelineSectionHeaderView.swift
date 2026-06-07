import DesignSystem
import SwiftUI

struct TimelineSectionHeaderView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(DSTypography.headline)
                .foregroundStyle(DSColors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.top, DSSpacing.md)
        .padding(.bottom, DSSpacing.xs)
        .accessibilityAddTraits(.isHeader)
    }
}
