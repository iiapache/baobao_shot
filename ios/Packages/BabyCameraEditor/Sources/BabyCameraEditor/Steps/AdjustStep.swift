import CoreImage
import Foundation

/// 调色参数；T2.12 将在 UI 层绑定滑杆。
public struct AdjustParameters: Codable, Equatable, Sendable {
    public var brightness: Double
    public var contrast: Double
    public var saturation: Double
    public var temperature: Double
    public var shadows: Double
    public var highlights: Double
    public var sharpness: Double

    public init(
        brightness: Double = 0,
        contrast: Double = 1,
        saturation: Double = 1,
        temperature: Double = 6500,
        shadows: Double = 0,
        highlights: Double = 0,
        sharpness: Double = 0
    ) {
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
        self.shadows = shadows
        self.highlights = highlights
        self.sharpness = sharpness
    }
}

/// 调色步骤。
public struct AdjustStep: EditStep {
    public var kind: EditStepKind { .adjust }

    public var parameters: AdjustParameters

    public init(parameters: AdjustParameters) {
        self.parameters = parameters
    }

    public func apply(to image: CIImage) -> CIImage {
        var output = image

        if parameters.brightness != 0 || parameters.contrast != 1 || parameters.saturation != 1 {
            guard let filter = CIFilter(name: "CIColorControls") else { return image }
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(parameters.brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(parameters.contrast, forKey: kCIInputContrastKey)
            filter.setValue(parameters.saturation, forKey: kCIInputSaturationKey)
            output = filter.outputImage ?? output
        }

        if parameters.sharpness != 0 {
            guard let filter = CIFilter(name: "CISharpenLuminance") else { return output }
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(parameters.sharpness, forKey: kCIInputSharpnessKey)
            output = filter.outputImage ?? output
        }

        return output
    }
}
