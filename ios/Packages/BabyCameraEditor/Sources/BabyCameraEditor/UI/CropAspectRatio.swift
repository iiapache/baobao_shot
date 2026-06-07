import Foundation

/// PRD §4.4 裁剪比例预设。
public enum CropAspectRatio: String, Codable, CaseIterable, Sendable {
    case free
    case square
    case portrait34
    case story916
    case landscape169

    public var displayName: String {
        switch self {
        case .free: "自由"
        case .square: "1:1"
        case .portrait34: "3:4"
        case .story916: "9:16"
        case .landscape169: "16:9"
        }
    }

    /// 宽 / 高；自由裁剪返回 `nil`。
    public var widthOverHeight: Double? {
        switch self {
        case .free: nil
        case .square: 1
        case .portrait34: 3.0 / 4.0
        case .story916: 9.0 / 16.0
        case .landscape169: 16.0 / 9.0
        }
    }
}

public extension NormalizedRect {
    static let full = NormalizedRect(x: 0, y: 0, width: 1, height: 1)

    /// 在容器内居中生成符合比例的裁剪框。
    static func centered(aspectRatio: CropAspectRatio, in container: NormalizedRect = .full) -> NormalizedRect {
        guard let ratio = aspectRatio.widthOverHeight else {
            return container
        }

        let containerRatio = container.width / container.height
        var width = container.width
        var height = container.height

        if containerRatio > ratio {
            width = container.height * ratio
        } else {
            height = container.width / ratio
        }

        return NormalizedRect(
            x: container.x + (container.width - width) / 2,
            y: container.y + (container.height - height) / 2,
            width: width,
            height: height
        )
    }
}
