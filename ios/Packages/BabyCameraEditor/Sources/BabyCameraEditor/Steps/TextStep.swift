import CoreImage
import Foundation

/// 文字步骤；字体 ID 与 `FontCatalog` manifest 对齐。
public struct TextStep: EditStep {
    public var kind: EditStepKind { .text }

    public var text: String
    /// manifest `postScriptName`，如 `BaobaoRounded-Regular`。
    public var fontName: String
    /// manifest `id`，如 `font_baobao_rounded`；序列化保留供 UI 恢复。
    public var fontID: String?
    public var fontSize: Double
    public var colorHex: String
    public var centerX: Double
    public var centerY: Double

    public init(
        text: String,
        fontName: String = FontCatalog.postScriptName(for: FontCatalog.defaultFontID),
        fontID: String? = FontCatalog.defaultFontID,
        fontSize: Double = 24,
        colorHex: String = "#FFFFFF",
        centerX: Double = 0.5,
        centerY: Double = 0.9
    ) {
        self.text = text
        self.fontName = fontName
        self.fontID = fontID
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.centerX = centerX
        self.centerY = centerY
    }

    public func apply(to image: CIImage) -> CIImage {
        #if canImport(UIKit)
        guard let textImage = TextImageRenderer.render(
            text: text,
            postScriptName: fontName,
            fontSize: CGFloat(fontSize),
            colorHex: colorHex,
            canvasExtent: image.extent
        ) else {
            return image
        }

        let extent = image.extent
        let center = CGPoint(
            x: extent.minX + extent.width * centerX,
            y: extent.minY + extent.height * centerY
        )
        let textExtent = textImage.extent
        let positioned = textImage.transformed(by: CGAffineTransform(
            translationX: center.x - textExtent.midX,
            y: center.y - textExtent.midY
        ))
        return positioned.composited(over: image)
        #else
        return image
        #endif
    }
}
