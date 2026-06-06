/// 缩略图最长边尺寸（像素）。
public enum ThumbnailSize: Int, Sendable, Equatable, CaseIterable {
    /// 列表 / 小组件小图
    case small = 256
    /// 详情 / 预览中图
    case medium = 1024

    public var maxEdgeLength: Int { rawValue }
}
