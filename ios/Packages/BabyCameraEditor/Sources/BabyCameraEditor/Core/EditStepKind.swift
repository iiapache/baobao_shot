import Foundation

/// 编辑步骤类型标识，用于 JSON 序列化与 UI 分类。
public enum EditStepKind: String, Codable, CaseIterable, Sendable {
    case filter
    case adjust
    case crop
    case rotate
    case sticker
    case text
    case mosaic
    case doodle
    case template
}
