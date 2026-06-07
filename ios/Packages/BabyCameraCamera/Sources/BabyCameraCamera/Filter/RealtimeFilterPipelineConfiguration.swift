import Foundation

/// `RealtimeFilterPipeline` 运行参数（design-ios §7.2：预览 30fps）。
public struct RealtimeFilterPipelineConfiguration: Equatable, Sendable, Codable {
    public var activeFilter: RealtimeFilterIdentifier
    /// 0…1，仅对支持强度的滤镜生效。
    public var filterIntensity: Double
    /// 预览帧率目标，默认 30fps。
    public var targetFrameRate: Int
    /// 实时预览关闭中间结果缓存以控制延迟。
    public var cacheIntermediates: Bool

    public static let `default` = RealtimeFilterPipelineConfiguration(
        activeFilter: .none,
        filterIntensity: 1.0,
        targetFrameRate: 30,
        cacheIntermediates: false
    )

    public init(
        activeFilter: RealtimeFilterIdentifier = .none,
        filterIntensity: Double = 1.0,
        targetFrameRate: Int = 30,
        cacheIntermediates: Bool = false
    ) {
        self.activeFilter = activeFilter
        self.filterIntensity = filterIntensity
        self.targetFrameRate = targetFrameRate
        self.cacheIntermediates = cacheIntermediates
    }

    /// 相邻帧最小间隔（秒），用于 30fps 节流。
    public var frameInterval: TimeInterval {
        guard targetFrameRate > 0 else { return 0 }
        return 1.0 / Double(targetFrameRate)
    }

    /// 切换滤镜时更新配置，强度回落到该滤镜默认值。
    public mutating func selectFilter(_ identifier: RealtimeFilterIdentifier) {
        activeFilter = identifier
        let preset = RealtimeFilterCatalog.preset(for: identifier)
        filterIntensity = preset.defaultIntensity
    }
}
