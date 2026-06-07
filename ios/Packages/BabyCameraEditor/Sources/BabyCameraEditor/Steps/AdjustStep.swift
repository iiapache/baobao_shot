import CoreImage
import Foundation

/// 调色参数；UI 滑杆通过 `AdjustParameterRanges` 绑定并 clamp。
public struct AdjustParameters: Codable, Equatable, Sendable {
    public var brightness: Double
    public var contrast: Double
    public var saturation: Double
    public var temperature: Double
    public var shadows: Double
    public var highlights: Double
    public var sharpness: Double

    public init(
        brightness: Double = AdjustParameterRanges.brightness.default,
        contrast: Double = AdjustParameterRanges.contrast.default,
        saturation: Double = AdjustParameterRanges.saturation.default,
        temperature: Double = AdjustParameterRanges.temperature.default,
        shadows: Double = AdjustParameterRanges.shadows.default,
        highlights: Double = AdjustParameterRanges.highlights.default,
        sharpness: Double = AdjustParameterRanges.sharpness.default
    ) {
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
        self.shadows = shadows
        self.highlights = highlights
        self.sharpness = sharpness
    }

    /// 返回 clamp 后的副本。
    public func clamped() -> AdjustParameters {
        AdjustParameterRanges.clamped(self)
    }

    public var isNeutral: Bool {
        self == AdjustParameters()
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
        let params = parameters.clamped()
        guard !params.isNeutral else { return image }

        var output = image

        if params.brightness != AdjustParameterRanges.brightness.default
            || params.contrast != AdjustParameterRanges.contrast.default
            || params.saturation != AdjustParameterRanges.saturation.default {
            guard let filter = CIFilter(name: "CIColorControls") else { return image }
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(params.brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(params.contrast, forKey: kCIInputContrastKey)
            filter.setValue(params.saturation, forKey: kCIInputSaturationKey)
            output = filter.outputImage ?? output
        }

        if params.temperature != AdjustParameterRanges.temperature.default {
            guard let filter = CIFilter(name: "CITemperatureAndTint") else { return output }
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter.setValue(CIVector(x: params.temperature, y: 0), forKey: "inputTargetNeutral")
            output = filter.outputImage ?? output
        }

        if params.shadows != AdjustParameterRanges.shadows.default
            || params.highlights != AdjustParameterRanges.highlights.default {
            guard let filter = CIFilter(name: "CIHighlightShadowAdjust") else { return output }
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(params.shadows, forKey: "inputShadowAmount")
            filter.setValue(params.highlights, forKey: "inputHighlightAmount")
            output = filter.outputImage ?? output
        }

        if params.sharpness != AdjustParameterRanges.sharpness.default {
            guard let filter = CIFilter(name: "CISharpenLuminance") else { return output }
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(params.sharpness, forKey: kCIInputSharpnessKey)
            output = filter.outputImage ?? output
        }

        return output
    }
}
