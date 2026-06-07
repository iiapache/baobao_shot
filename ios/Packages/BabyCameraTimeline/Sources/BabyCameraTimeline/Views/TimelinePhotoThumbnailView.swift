import DesignSystem
import SwiftUI

struct TimelinePhotoThumbnailView: View {
    let item: TimelinePhotoItem
    let columnCount: Int
    @ObservedObject var thumbnailLoader: TimelineThumbnailLoader
    var onTap: (() -> Void)?

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    thumbnailContent
                }
                .buttonStyle(.plain)
            } else {
                thumbnailContent
            }
        }
        .accessibilityLabel("照片")
        .accessibilityIdentifier("timelinePhoto-\(item.id)")
        .task(id: item.filePath) {
            image = await thumbnailLoader.loadImage(for: item.filePath)
        }
    }

    private var thumbnailContent: some View {
        GeometryReader { geometry in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(DSColors.surfaceGrouped)
                    ProgressView()
                        .tint(DSColors.primary)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
