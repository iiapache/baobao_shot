import DesignSystem
import SwiftUI

struct PostWatermarkPreviewCard: View {
    let previewImage: UIImage?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("水印预览")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)

            Group {
                if isLoading {
                    DSLoadingView(message: "生成预览…")
                        .frame(height: 160)
                } else if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
                        .accessibilityLabel("带水印的预览图")
                } else {
                    DSEmptyState(
                        title: "暂无预览",
                        message: "添加图片后可预览品牌水印与深度合成角标",
                        systemImage: "photo.badge.checkmark"
                    )
                    .frame(height: 160)
                }
            }
            .frame(maxWidth: .infinity)
            .background(DSColors.surfaceGrouped)
            .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        }
    }
}
