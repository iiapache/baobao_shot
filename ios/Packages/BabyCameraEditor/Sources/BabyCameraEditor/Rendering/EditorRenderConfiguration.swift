import Foundation

/// 编辑器离屏渲染与导出约束（design-ios §8.3）。
public struct EditorRenderConfiguration: Sendable, Equatable {
    /// 导出最长边上限（像素）。
    public static let defaultMaxExportDimension = 8000
    /// 大图导出内存峰值预算（字节）。
    public static let defaultMaxMemoryBytes = 200 * 1024 * 1024
    /// CIContext / 编码器等固定开销预留。
    public static let defaultMemoryOverheadBytes = 32 * 1024 * 1024

    public var maxExportDimension: Int
    public var maxMemoryBytes: Int
    public var memoryOverheadBytes: Int

    public init(
        maxExportDimension: Int = Self.defaultMaxExportDimension,
        maxMemoryBytes: Int = Self.defaultMaxMemoryBytes,
        memoryOverheadBytes: Int = Self.defaultMemoryOverheadBytes
    ) {
        self.maxExportDimension = maxExportDimension
        self.maxMemoryBytes = maxMemoryBytes
        self.memoryOverheadBytes = memoryOverheadBytes
    }

    public static let `default` = EditorRenderConfiguration()
}
