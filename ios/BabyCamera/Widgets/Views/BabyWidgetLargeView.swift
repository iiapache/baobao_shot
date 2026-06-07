import SwiftUI
import WidgetKit
import Widgets

struct BabyWidgetLargeView: View {
    let content: BabyWidgetTimelineContent

    private var gridPaths: [String?] {
        var paths = content.weekPhotoThumbnailPaths.map(Optional.some)
        while paths.count < BabyWidgetTimelineContentBuilder.largeWidgetPhotoCount {
            paths.append(nil)
        }
        return Array(paths.prefix(BabyWidgetTimelineContentBuilder.largeWidgetPhotoCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(content.babyName)
                    .font(.headline)
                    .foregroundStyle(BabyWidgetStyle.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(BabyWidgetStyle.growthDaysLabel(content.growthDays))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BabyWidgetStyle.accent)
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 8),
                    count: 2
                ),
                spacing: 8
            ) {
                ForEach(Array(gridPaths.enumerated()), id: \.offset) { _, path in
                    BabyWidgetImageView(relativePath: path)
                        .frame(minHeight: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(14)
    }
}

struct BabyCameraLargeWidget: Widget {
    let kind: String = BabyWidgetKind.large.identifier

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyWidgetTimelineProvider()) { entry in
            BabyWidgetStyle.widgetBackground(BabyWidgetStyle.background) {
                BabyWidgetLargeView(content: entry.content)
            }
        }
        .configurationDisplayName("本周瞬间")
        .description("最近 4 天代表图宫格")
        .supportedFamilies([.systemLarge])
    }
}
