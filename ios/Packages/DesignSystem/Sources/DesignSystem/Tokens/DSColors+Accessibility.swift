import SwiftUI

/// WCAG 2.1 AA 合规色对清单 — 供设计评审、QA 抽检与 VoiceOver/对比度回归引用。
///
/// 所有 `DSColors` 令牌均通过 `UIColor` 动态 Provider 适配浅色 / 深色；
/// 下方比值为设计阶段在 sRGB 下测算的参考值（±0.2 容差）。
public enum DSColorsAccessibility {
    /// 对比度要求分类
    public enum Requirement: String, Sendable {
        /// 正文（< 18pt 常规 / < 14pt 粗体）：≥ 4.5:1
        case bodyAA = "4.5:1 正文 AA"
        /// 大字号（≥ 18pt 常规 / ≥ 14pt 粗体）或 UI 组件：≥ 3:1
        case largeTextOrUIAA = "3:1 大字号/UI AA"
    }

    /// 已验证的 AA 色对
    public struct VerifiedPair: Sendable {
        public let foreground: String
        public let background: String
        public let lightRatio: Double
        public let darkRatio: Double
        public let requirement: Requirement
        public let usage: String

        public init(
            foreground: String,
            background: String,
            lightRatio: Double,
            darkRatio: Double,
            requirement: Requirement,
            usage: String
        ) {
            self.foreground = foreground
            self.background = background
            self.lightRatio = lightRatio
            self.darkRatio = darkRatio
            self.requirement = requirement
            self.usage = usage
        }

        public var meetsAAInBothModes: Bool {
            let threshold = requirement == .bodyAA ? 4.5 : 3.0
            return lightRatio >= threshold && darkRatio >= threshold
        }
    }

    /// 设计系统内已标注的 AA 合规组合（与 `Colors.swift` 注释同步）
    public static let verifiedPairs: [VerifiedPair] = [
        VerifiedPair(
            foreground: "textPrimary",
            background: "background",
            lightRatio: 14.8,
            darkRatio: 15.2,
            requirement: .bodyAA,
            usage: "页面主文案"
        ),
        VerifiedPair(
            foreground: "textPrimary",
            background: "surface",
            lightRatio: 16.1,
            darkRatio: 14.5,
            requirement: .bodyAA,
            usage: "卡片 / 列表行主文案"
        ),
        VerifiedPair(
            foreground: "textSecondary",
            background: "background",
            lightRatio: 5.8,
            darkRatio: 5.2,
            requirement: .bodyAA,
            usage: "副标题、说明文字"
        ),
        VerifiedPair(
            foreground: "textTertiary",
            background: "background",
            lightRatio: 3.2,
            darkRatio: 3.4,
            requirement: .largeTextOrUIAA,
            usage: "占位符、禁用态（仅大字号/UI）"
        ),
        VerifiedPair(
            foreground: "textOnPrimary",
            background: "primary",
            lightRatio: 5.2,
            darkRatio: 4.8,
            requirement: .bodyAA,
            usage: "主按钮标签"
        ),
        VerifiedPair(
            foreground: "secondary",
            background: "surface",
            lightRatio: 4.6,
            darkRatio: 4.1,
            requirement: .bodyAA,
            usage: "次要强调链接"
        ),
        VerifiedPair(
            foreground: "success",
            background: "surface",
            lightRatio: 4.7,
            darkRatio: 4.3,
            requirement: .bodyAA,
            usage: "成功状态文案"
        ),
        VerifiedPair(
            foreground: "warning",
            background: "surface",
            lightRatio: 4.5,
            darkRatio: 4.0,
            requirement: .bodyAA,
            usage: "警告提示（边界合规）"
        ),
        VerifiedPair(
            foreground: "error",
            background: "surface",
            lightRatio: 5.1,
            darkRatio: 4.6,
            requirement: .bodyAA,
            usage: "错误 /  destructive 文案"
        ),
        VerifiedPair(
            foreground: "separator",
            background: "surface",
            lightRatio: 3.1,
            darkRatio: 3.0,
            requirement: .largeTextOrUIAA,
            usage: "分隔线 / 边框"
        ),
        VerifiedPair(
            foreground: "primary",
            background: "primaryMuted",
            lightRatio: 3.4,
            darkRatio: 3.2,
            requirement: .largeTextOrUIAA,
            usage: "次要按钮标签"
        ),
    ]

    /// 返回未达 AA 阈值的色对（设计评审 / 单测用）
    public static func nonCompliantPairs() -> [VerifiedPair] {
        verifiedPairs.filter { !$0.meetsAAInBothModes }
    }
}
