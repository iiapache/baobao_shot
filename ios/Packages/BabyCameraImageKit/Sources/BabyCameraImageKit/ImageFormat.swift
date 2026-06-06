import UniformTypeIdentifiers

/// 支持的图片编码格式。
public enum ImageFormat: String, Sendable, Equatable, CaseIterable {
    case heic
    case jpeg

    /// 对应 UTType 标识符，供 ImageIO 使用。
    public var utTypeIdentifier: String {
        switch self {
        case .heic:
            return UTType.heic.identifier
        case .jpeg:
            return UTType.jpeg.identifier
        }
    }

    /// 文件扩展名（小写，不含点）。
    public var fileExtension: String {
        switch self {
        case .heic:
            return "heic"
        case .jpeg:
            return "jpg"
        }
    }
}
