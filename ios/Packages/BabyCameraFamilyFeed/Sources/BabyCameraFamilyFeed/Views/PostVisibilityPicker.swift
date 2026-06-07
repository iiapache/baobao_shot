import BabyCameraNetwork
import DesignSystem
import SwiftUI

struct PostVisibilityPicker: View {
    @Binding var visibility: PostVisibility

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("可见范围")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)

            Picker("可见范围", selection: $visibility) {
                Text("家庭").tag(PostVisibility.family)
                Text("仅自己").tag(PostVisibility.selfOnly)
            }
            .pickerStyle(.segmented)
        }
        .accessibilityElement(children: .contain)
    }
}
