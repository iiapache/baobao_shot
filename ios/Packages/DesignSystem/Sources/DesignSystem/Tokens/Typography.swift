import SwiftUI

/// 排版令牌 — 全部基于系统文本样式，自动支持 Dynamic Type。
///
/// 禁止硬编码 `.system(size:)`（图标除外，见各组件注释）。
/// 用户调整「设置 → 显示与亮度 → 文字大小」后，布局应能随字号缩放。
public enum DSTypography {
    // MARK: - Display & Titles

    public static let largeTitle = Font.largeTitle.weight(.bold)
    public static let title = Font.title.weight(.semibold)
    public static let title2 = Font.title2.weight(.semibold)
    public static let title3 = Font.title3.weight(.semibold)

    // MARK: - Body

    public static let headline = Font.headline
    public static let body = Font.body
    public static let bodyEmphasis = Font.body.weight(.semibold)
    public static let callout = Font.callout
    public static let subheadline = Font.subheadline

    // MARK: - Supporting

    public static let footnote = Font.footnote
    public static let caption = Font.caption
    public static let caption2 = Font.caption2

    // MARK: - Component Presets

    /// 主按钮标签
    public static let buttonLarge = Font.body.weight(.semibold)
    public static let buttonMedium = Font.callout.weight(.semibold)
    public static let buttonSmall = Font.footnote.weight(.semibold)

    /// 列表行标题 / 副标题
    public static let listTitle = Font.body.weight(.medium)
    public static let listSubtitle = Font.subheadline

    /// 空态标题 / 说明
    public static let emptyTitle = Font.title3.weight(.semibold)
    public static let emptyMessage = Font.body

    /// Loading 提示
    public static let loadingMessage = Font.subheadline
}
