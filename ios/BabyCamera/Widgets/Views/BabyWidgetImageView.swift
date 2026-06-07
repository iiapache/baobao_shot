import SwiftUI
import WidgetKit
import Widgets

struct BabyWidgetImageView: View {
    let relativePath: String?
    var fallbackSystemName: String = "photo"

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackSystemName)
                    .font(.title2)
                    .foregroundStyle(BabyWidgetStyle.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.6))
            }
        }
        .clipped()
    }

    private func loadImage() -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetAppGroupConfiguration.groupIdentifier
        ) else {
            return nil
        }

        guard let fileURL = BabyWidgetThumbnailResolver.resolveURL(
            relativePath: relativePath,
            containerURL: containerURL
        ) else {
            return nil
        }

        return UIImage(contentsOfFile: fileURL.path)
    }
}
