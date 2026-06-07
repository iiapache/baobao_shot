import SwiftUI
import WidgetKit
import Widgets

struct BabyWidgetMediumView: View {
    let content: BabyWidgetTimelineContent

    var body: some View {
        HStack(spacing: 12) {
            BabyWidgetImageView(relativePath: content.todayPhotoThumbnailPath)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(content.babyName)
                    .font(.headline)
                    .foregroundStyle(BabyWidgetStyle.textPrimary)
                    .lineLimit(1)

                Text(BabyWidgetStyle.growthDaysLabel(content.growthDays))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BabyWidgetStyle.accent)

                Text("今日代表瞬间")
                    .font(.caption)
                    .foregroundStyle(BabyWidgetStyle.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

struct BabyCameraMediumWidget: Widget {
    let kind: String = BabyWidgetKind.medium.identifier

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyWidgetTimelineProvider()) { entry in
            BabyWidgetStyle.widgetBackground(BabyWidgetStyle.background) {
                BabyWidgetMediumView(content: entry.content)
            }
        }
        .configurationDisplayName("今日瞬间")
        .description("当日代表图与成长天数")
        .supportedFamilies([.systemMedium])
    }
}
