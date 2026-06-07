import Foundation

/// 单款编辑器滤镜的元数据与 Core Image 映射。
public struct FilterPreset: Equatable, Sendable, Identifiable {
    public var id: FilterIdentifier
    public var category: FilterCategory
    public var displayName: String
    /// `nil` 表示直通原图。
    public var ciFilterName: String?
    /// 可调强度滤镜的参数键（如 `kCIInputIntensityKey`）。
    public var intensityParameterKey: String?
    public var defaultIntensity: Double

    public init(
        id: FilterIdentifier,
        category: FilterCategory,
        displayName: String,
        ciFilterName: String? = nil,
        intensityParameterKey: String? = nil,
        defaultIntensity: Double = 1.0
    ) {
        self.id = id
        self.category = category
        self.displayName = displayName
        self.ciFilterName = ciFilterName
        self.intensityParameterKey = intensityParameterKey
        self.defaultIntensity = defaultIntensity
    }

    /// 是否支持通过 `FilterStep.intensity` 直接驱动滤镜内置参数（而非与原图混合）。
    public var usesBuiltInIntensityParameter: Bool {
        intensityParameterKey != nil
    }
}
