import CoreGraphics
import Foundation

/// 深度合成显式角标布局（右下角，PRD §6.2 / compliance DEEP_SYNTHESIS_CHECKLIST §2.1）。
public enum DeepSynthesisBadgeLayout: Sendable {
    /// 锚点：右下角。
    public static let anchor: DeepSynthesisBadgeAnchor = .bottomRight

    /// 角标宽度相对短边比例（6%，合规 5–8% 区间）。
    public static let widthRatio: CGFloat = 0.06

    /// 相对短边的边距比例。
    public static let marginRatio: CGFloat = 0.01

    /// 背景不透明度（60%）。
    public static let backgroundOpacity: CGFloat = 0.6

    /// 文字不透明度（100%）。
    public static let textOpacity: CGFloat = 1.0

    /// 角标文案（与 ai-dispatch-svc watermark/constants.go 一致）。
    public static let badgeText = "AI 生成 · 深度合成"

    /// 背景相对字号的水平内边距比例。
    public static let horizontalPaddingRatio: CGFloat = 0.35

    /// 背景相对字号的垂直内边距比例。
    public static let verticalPaddingRatio: CGFloat = 0.22

    public static func margin(for canvasSize: CGSize) -> CGFloat {
        max(4, min(canvasSize.width, canvasSize.height) * marginRatio)
    }

    /// 目标角标宽度（短边 * widthRatio，最小 48pt）。
    public static func targetWidth(for canvasSize: CGSize) -> CGFloat {
        max(48, min(canvasSize.width, canvasSize.height) * widthRatio)
    }

    /// 根据目标宽度反推字号，使文字宽度适配角标区域。
    public static func fontSize(for canvasSize: CGSize) -> CGFloat {
        let target = targetWidth(for: canvasSize)
        var size = target * 0.18
        let measured = measuredTextSize(fontSize: size)
        if measured.width > 0 {
            size *= target / measured.width
        }
        return max(10, size)
    }

    /// CoreGraphics 坐标系下背景矩形（原点左上）。
    public static func backgroundRect(canvasSize: CGSize) -> CGRect {
        let margin = margin(for: canvasSize)
        let fontSize = fontSize(for: canvasSize)
        let textSize = measuredTextSize(fontSize: fontSize)
        let padX = fontSize * horizontalPaddingRatio
        let padY = fontSize * verticalPaddingRatio
        let width = textSize.width + padX * 2
        let height = textSize.height + padY * 2
        return CGRect(
            x: canvasSize.width - margin - width,
            y: canvasSize.height - margin - height,
            width: width,
            height: height
        )
    }

    /// CoreGraphics 坐标系下文字绘制原点。
    public static func textOrigin(canvasSize: CGSize) -> CGPoint {
        let rect = backgroundRect(canvasSize: canvasSize)
        let fontSize = fontSize(for: canvasSize)
        let textSize = measuredTextSize(fontSize: fontSize)
        let padX = fontSize * horizontalPaddingRatio
        let padY = fontSize * verticalPaddingRatio
        return CGPoint(
            x: rect.minX + padX,
            y: rect.minY + padY + (rect.height - padY * 2 - textSize.height) / 2
        )
    }

    static func measuredTextSize(fontSize: CGFloat) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: DeepSynthesisBadgeTextStyle.uiFont(size: fontSize),
        ]
        let rect = (badgeText as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }
}

public enum DeepSynthesisBadgeAnchor: Sendable, Equatable {
    case bottomRight
}
