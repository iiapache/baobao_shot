import Foundation

/// design-assets/stickers/manifest.json 解码模型。
struct StickerManifest: Codable, Sendable {
    var schemaVersion: String
    var categories: [StickerCategoryRecord]
    var stickers: [StickerRecord]
}

struct StickerCategoryRecord: Codable, Sendable {
    var id: String
    var name: String
    var sort: Int
    var description: String?
}

struct StickerRecord: Codable, Sendable {
    var id: String
    var category: String
    var categoryLabel: String
    var name: String
    var file: String
    var size: StickerSizeRecord
    var defaultScale: Double
    var odrTag: String?
}

struct StickerSizeRecord: Codable, Sendable {
    var width: Int
    var height: Int
}

/// 贴纸分类标识，与 manifest `categories[].id` 对齐。
public enum StickerCategoryID: String, Codable, CaseIterable, Sendable {
    case numbers
    case festivals
    case text
    case animals
    case food
    case daily
    case milestones
    case cute

    public var displayName: String {
        switch self {
        case .numbers: "数字"
        case .festivals: "节日"
        case .text: "文字"
        case .animals: "动物"
        case .food: "食物"
        case .daily: "日常"
        case .milestones: "里程碑"
        case .cute: "可爱表情"
        }
    }
}

/// 运行时贴纸条目，供 UI 与 `StickerStep` 引用。
public struct StickerAsset: Equatable, Sendable, Identifiable {
    public var id: String
    public var category: StickerCategoryID
    public var categoryLabel: String
    public var name: String
    public var filePath: String
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var defaultScale: Double
    public var odrTag: String

    init(record: StickerRecord) {
        id = record.id
        category = StickerCategoryID(rawValue: record.category) ?? .cute
        categoryLabel = record.categoryLabel
        name = record.name
        filePath = record.file
        pixelWidth = record.size.width
        pixelHeight = record.size.height
        defaultScale = record.defaultScale
        odrTag = record.odrTag ?? "editor-stickers"
    }
}

/// 贴纸分类元数据。
public struct StickerCategory: Equatable, Sendable, Identifiable {
    public var id: StickerCategoryID
    public var name: String
    public var sort: Int
    public var description: String?

    init(record: StickerCategoryRecord) {
        id = StickerCategoryID(rawValue: record.id) ?? .cute
        name = record.name
        sort = record.sort
        description = record.description
    }
}
