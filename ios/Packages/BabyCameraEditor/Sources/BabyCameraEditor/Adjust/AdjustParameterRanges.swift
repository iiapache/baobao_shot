import Foundation

/// 调色滑杆范围（T2.12 UI 绑定与 clamp 共用）。
public enum AdjustParameterRanges {
    public struct Range: Equatable, Sendable {
        public let min: Double
        public let max: Double
        public let `default`: Double

        public init(min: Double, max: Double, default defaultValue: Double) {
            self.min = min
            self.max = max
            self.default = defaultValue
        }

        public func clamp(_ value: Double) -> Double {
            Swift.min(Swift.max(value, min), max)
        }

        /// 将实际值映射到 0…1，供 UI 滑杆绑定。
        public func normalized(_ value: Double) -> Double {
            guard max > min else { return 0 }
            let clampedValue = clamp(value)
            return (clampedValue - min) / (max - min)
        }

        /// 将 0…1 滑杆值还原为实际参数。
        public func denormalized(_ normalized: Double) -> Double {
            let t = Swift.min(Swift.max(normalized, 0), 1)
            return min + t * (max - min)
        }
    }

    public static let brightness = Range(min: -0.5, max: 0.5, default: 0)
    public static let contrast = Range(min: 0.5, max: 1.5, default: 1)
    public static let saturation = Range(min: 0, max: 2, default: 1)
    public static let temperature = Range(min: 3000, max: 9000, default: 6500)
    public static let shadows = Range(min: -1, max: 1, default: 0)
    public static let highlights = Range(min: -1, max: 1, default: 0)
    public static let sharpness = Range(min: 0, max: 1, default: 0)

    /// 将所有参数 clamp 到合法范围。
    public static func clamped(_ parameters: AdjustParameters) -> AdjustParameters {
        AdjustParameters(
            brightness: brightness.clamp(parameters.brightness),
            contrast: contrast.clamp(parameters.contrast),
            saturation: saturation.clamp(parameters.saturation),
            temperature: temperature.clamp(parameters.temperature),
            shadows: shadows.clamp(parameters.shadows),
            highlights: highlights.clamp(parameters.highlights),
            sharpness: sharpness.clamp(parameters.sharpness)
        )
    }
}
