import SwiftUI
import WidgetKit
import Widgets

struct BabyWidgetLockScreenView: View {
    let content: BabyWidgetTimelineContent

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                Text(content.growthDays > 0 ? "\(content.growthDays)" : "—")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("天")
                    .font(.system(size: 9, weight: .medium))
            }
        }
    }
}

struct BabyCameraLockScreenWidget: Widget {
    let kind: String = BabyWidgetKind.lockScreen.identifier

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyWidgetTimelineProvider()) { entry in
            BabyWidgetLockScreenView(content: entry.content)
        }
        .configurationDisplayName("成长天数")
        .description("锁屏角标显示当前成长天数")
        .supportedFamilies([.accessoryCircular])
    }
}
