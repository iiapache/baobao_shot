import CoreImage
import Foundation

/// 贴纸步骤；T2.13 将绑定本地贴纸资源库。
public struct StickerStep: EditStep {
    public var kind: EditStepKind { .sticker }

    public var resourceID: String
    public var centerX: Double
    public var centerY: Double
    public var scale: Double
    public var rotationDegrees: Double

    public init(
        resourceID: String,
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        scale: Double = 1.0,
        rotationDegrees: Double = 0
    ) {
        self.resourceID = resourceID
        self.centerX = centerX
        self.centerY = centerY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
    }

    public func apply(to image: CIImage) -> CIImage {
        // 内核占位：用半透明色块标记贴纸位置，T2.13 替换为真实合成。
        let extent = image.extent
        let size = min(extent.width, extent.height) * 0.15 * scale
        let center = CGPoint(
            x: extent.minX + extent.width * centerX,
            y: extent.minY + extent.height * centerY
        )
        let stickerRect = CGRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )

        guard let overlay = CIFilter(
            name: "CIConstantColorGenerator",
            parameters: [
                kCIInputColorKey: CIColor(red: 1, green: 0.8, blue: 0.2, alpha: 0.6),
            ]
        )?.outputImage?.cropped(to: stickerRect) else {
            return image
        }

        let rotated = overlay.transformed(by: CGAffineTransform(rotationAngle: rotationDegrees * .pi / 180))
        return rotated.composited(over: image)
    }
}
