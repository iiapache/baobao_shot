import Foundation

/// 单款实时滤镜的元数据与 Core Image 映射。
public struct RealtimeFilterPreset: Equatable, Sendable, Identifiable {
    public var id: RealtimeFilterIdentifier
    public var displayName: String
    /// `nil` 表示直通原图。
    public var ciFilterName: String?
    /// 可调强度滤镜的参数键（如 `kCIInputIntensityKey`）。
    public var intensityParameterKey: String?
    public var defaultIntensity: Double

    public init(
        id: RealtimeFilterIdentifier,
        displayName: String,
        ciFilterName: String? = nil,
        intensityParameterKey: String? = nil,
        defaultIntensity: Double = 1.0
    ) {
        self.id = id
        self.displayName = displayName
        self.ciFilterName = ciFilterName
        self.intensityParameterKey = intensityParameterKey
        self.defaultIntensity = defaultIntensity
    }
}
