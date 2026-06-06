import CoreImage
import Foundation

/// 文字步骤；T2.13 将绑定字体资源与 UI 编辑。
public struct TextStep: EditStep {
    public var kind: EditStepKind { .text }

    public var text: String
    public var fontName: String
    public var fontSize: Double
    public var colorHex: String
    public var centerX: Double
    public var centerY: Double

    public init(
        text: String,
        fontName: String = "PingFangSC-Regular",
        fontSize: Double = 24,
        colorHex: String = "#FFFFFF",
        centerX: Double = 0.5,
        centerY: Double = 0.9
    ) {
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.centerX = centerX
        self.centerY = centerY
    }

    public func apply(to image: CIImage) -> CIImage {
        // 内核占位：文字渲染在 T2.13 EditorRenderer 中实现；此处保持幂等。
        _ = (text, fontName, fontSize, colorHex, centerX, centerY)
        return image
    }
}
