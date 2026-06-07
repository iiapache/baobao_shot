import SwiftUI
import WidgetKit
import Widgets

struct BabyWidgetSmallView: View {
    let content: BabyWidgetTimelineContent

    var body: some View {
        VStack(spacing: 8) {
                BabyWidgetImageView(
                    relativePath: content.avatarThumbnailPath,
                    fallbackSystemName: "face.smiling"
                )
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(BabyWidgetStyle.accent.opacity(0.35), lineWidth: 2))

                Text(content.babyName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BabyWidgetStyle.textPrimary)
                    .lineLimit(1)

                Text(BabyWidgetStyle.growthDaysLabel(content.growthDays))
                    .font(.caption2)
                    .foregroundStyle(BabyWidgetStyle.accent)
        }
        .padding(12)
    }
}

struct BabyCameraSmallWidget: Widget {
    let kind: String = BabyWidgetKind.small.identifier

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyWidgetTimelineProvider()) { entry in
            BabyWidgetStyle.widgetBackground(BabyWidgetStyle.background) {
                BabyWidgetSmallView(content: entry.content)
            }
        }
        .configurationDisplayName("宝宝成长")
        .description("头像与成长天数")
        .supportedFamilies([.systemSmall])
    }
}
