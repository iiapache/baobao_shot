import CoreImage
import Foundation

/// 贴纸步骤；`resourceID` 对应 stickers manifest `id`。
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
        StickerCatalog.apply(step: self, to: image)
    }
}
