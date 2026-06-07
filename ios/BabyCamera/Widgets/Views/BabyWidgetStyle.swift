import SwiftUI
import WidgetKit

enum BabyWidgetStyle {
    @ViewBuilder
    static func widgetBackground<Content: View>(_ color: Color, @ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 17.0, *) {
            content()
                .containerBackground(for: .widget) {
                    color
                }
        } else {
            ZStack {
                color
                content()
            }
        }
    }
    static let accent = Color(red: 0.98, green: 0.45, blue: 0.55)
    static let background = Color(red: 1.0, green: 0.97, blue: 0.95)
    static let textPrimary = Color(red: 0.18, green: 0.16, blue: 0.20)
    static let textSecondary = Color(red: 0.45, green: 0.42, blue: 0.48)

    static func growthDaysLabel(_ days: Int) -> String {
        days > 0 ? "第 \(days) 天" : "成长记录"
    }
}
