import CoreImage
import Foundation

/// 马赛克步骤。
public struct MosaicStep: EditStep {
    public var kind: EditStepKind { .mosaic }

    public var region: NormalizedRect
    public var blockSize: Double

    public init(region: NormalizedRect, blockSize: Double = 16) {
        self.region = region
        self.blockSize = blockSize
    }

    public func apply(to image: CIImage) -> CIImage {
        let pixelRect = region.pixelRect(for: image.extent)
        let cropped = image.cropped(to: pixelRect)

        guard let pixellate = CIFilter(name: "CIPixellate") else { return image }
        pixellate.setValue(cropped, forKey: kCIInputImageKey)
        pixellate.setValue(blockSize, forKey: kCIInputScaleKey)

        guard let mosaic = pixellate.outputImage?.cropped(to: pixelRect) else { return image }
        return mosaic.composited(over: image)
    }
}
