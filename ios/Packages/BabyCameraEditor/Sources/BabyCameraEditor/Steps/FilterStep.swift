import CoreImage
import Foundation

/// 内置滤镜标识（T2.12：≥ 12 款，见 `FilterCatalog`）。
public enum FilterIdentifier: String, Codable, CaseIterable, Sendable {
    case none

    // 日常
    case vivid
    case fade
    case instant

    // 人像
    case mono
    case transfer
    case softGlow

    // 胶片
    case sepia
    case chrome
    case tonal
    case noir

    // 卡通
    case posterize
    case comic
    case sketch
}

/// 滤镜步骤。
public struct FilterStep: EditStep {
    public var kind: EditStepKind { .filter }

    public var filterID: FilterIdentifier
    /// 0…1；对支持内置强度键的滤镜直接映射参数，否则与原图混合。
    public var intensity: Double

    public init(filterID: FilterIdentifier, intensity: Double = 1.0) {
        self.filterID = filterID
        self.intensity = intensity
    }

    public func apply(to image: CIImage) -> CIImage {
        FilterCatalog.apply(step: self, to: image)
    }
}
