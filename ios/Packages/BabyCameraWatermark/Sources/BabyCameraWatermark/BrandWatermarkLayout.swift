import CoreGraphics
import Foundation

/// 品牌水印布局常量（左下角小尺寸，PRD §4.10.2）。
public enum BrandWatermarkLayout: Sendable {
    /// 锚点：左下角（CI / CG 坐标系原点左下）。
    public static let anchor: BrandWatermarkAnchor = .bottomLeft

    /// 相对短边的边距比例。
    public static let marginRatio: CGFloat = 0.024

    /// 相对短边的字号比例（小尺寸水印）。
    public static let fontSizeRatio: CGFloat = 0.022

    /// 水印文字不透明度。
    public static let textOpacity: CGFloat = 0.72

    /// 品牌文案。
    public static let brandText = "宝宝成长相机"

    /// 根据画布尺寸计算左下角文本绘制原点（CoreGraphics 坐标，原点左上）。
    public static func textOrigin(canvasSize: CGSize) -> CGPoint {
        let shortEdge = min(canvasSize.width, canvasSize.height)
        let margin = shortEdge * marginRatio
        let fontSize = shortEdge * fontSizeRatio
        let textSize = measuredTextSize(fontSize: fontSize)
        return CGPoint(
            x: margin,
            y: canvasSize.height - margin - textSize.height
        )
    }

    /// 根据画布尺寸计算左下角文本绘制原点（CIImage 坐标，原点左下）。
    public static func ciTextOrigin(canvasSize: CGSize) -> CGPoint {
        let shortEdge = min(canvasSize.width, canvasSize.height)
        let margin = shortEdge * marginRatio
        return CGPoint(x: margin, y: margin)
    }

    public static func margin(for canvasSize: CGSize) -> CGFloat {
        min(canvasSize.width, canvasSize.height) * marginRatio
    }

    public static func fontSize(for canvasSize: CGSize) -> CGFloat {
        min(canvasSize.width, canvasSize.height) * fontSizeRatio
    }

    static func measuredTextSize(fontSize: CGFloat) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: BrandWatermarkTextStyle.uiFont(size: fontSize),
        ]
        let rect = (brandText as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }
}

public enum BrandWatermarkAnchor: Sendable, Equatable {
    case bottomLeft
}
