import DesignSystem
import SwiftUI

struct PostMediaGridView: View {
    let items: [PostComposerMediaItem]
    let onRemove: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.xs),
        GridItem(.flexible(), spacing: DSSpacing.xs),
        GridItem(.flexible(), spacing: DSSpacing.xs),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("媒体（最多 9 图 + 1 视频）")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)

            if items.isEmpty {
                Text("尚未添加媒体")
                    .font(DSTypography.footnote)
                    .foregroundStyle(DSColors.textTertiary)
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.xs) {
                    ForEach(items) { item in
                        PostMediaThumbnail(item: item, onRemove: { onRemove(item.id) })
                    }
                }
            }
        }
    }
}

private struct PostMediaThumbnail: View {
    let item: PostComposerMediaItem
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnail
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(4)
            .accessibilityLabel("移除媒体")
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = item.previewData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                DSColors.surfaceGrouped
                Image(systemName: item.kind == .video ? "video.fill" : "photo")
                    .font(.title2)
                    .foregroundStyle(DSColors.textSecondary)
            }
        }
    }
}
