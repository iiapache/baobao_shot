import Foundation

/// design-assets/templates/manifest.json 总 manifest 解码模型（仅 JSON，无可执行代码）。
struct TemplateCatalogManifest: Codable, Sendable {
    var schemaVersion: String
    var taskRef: String?
    var description: String?
    var minAppVersion: String?
    var categories: [TemplateCategoryRecord]
    var templates: [TemplateSummaryRecord]
}

struct TemplateCategoryRecord: Codable, Sendable {
    var id: String
    var name: String
    var sort: Int
}

struct TemplateSummaryRecord: Codable, Sendable {
    var id: String
    var name: String
    var category: String
    var categoryLabel: String
    var manifestPath: String
    var preview: String
    var remoteConfigurable: Bool
    var configSvcKey: String
}

/// 单套模板 manifest（design-assets/templates/*/manifest.json）。
struct TemplateDetailManifest: Codable, Sendable {
    var schemaVersion: String
    var taskRef: String?
    var id: String
    var name: String
    var category: String
    var categoryLabel: String
    var description: String?
    var preview: String?
    var thumbnail: String?
    var canvas: TemplateCanvasRecord
    var placeholders: [TemplatePlaceholderRecord]
    var steps: [AnyEditStep]
    var resources: TemplateResourcesRecord
    var remoteConfigurable: Bool?
    var configSvcKey: String?
    var minAppVersion: String?
    var editorStepType: String?
}

struct TemplateCanvasRecord: Codable, Sendable {
    var width: Int
    var height: Int
    var dpi: Int?
}

struct TemplatePlaceholderRecord: Codable, Sendable {
    var id: String
    var type: String
    var label: String
    var fontId: String?
    var defaultValue: String?
    var rect: NormalizedRect
    var aspectRatio: String?
    var editable: Bool?
}

struct TemplateResourcesRecord: Codable, Sendable {
    var background: String
    var overlay: String
    var fonts: [String]
    var stickers: [String]
}

/// 模板分类标识，与 manifest `categories[].id` 对齐。
public enum TemplateCategoryID: String, Codable, CaseIterable, Sendable {
    case growthCard = "growth-card"
    case hundredDay = "hundred-day"
    case firstBirthday = "first-birthday"

    public var displayName: String {
        switch self {
        case .growthCard: "成长卡片"
        case .hundredDay: "百天卡"
        case .firstBirthday: "周岁卡"
        }
    }
}

/// 运行时模板摘要条目，供 UI 与 `TemplateStep` 引用。
public struct TemplateAsset: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var category: TemplateCategoryID
    public var categoryLabel: String
    public var manifestPath: String
    public var previewPath: String
    public var remoteConfigurable: Bool
    public var configSvcKey: String

    init(record: TemplateSummaryRecord) {
        id = record.id
        name = record.name
        category = TemplateCategoryID(rawValue: record.category) ?? .growthCard
        categoryLabel = record.categoryLabel
        manifestPath = record.manifestPath
        previewPath = record.preview
        remoteConfigurable = record.remoteConfigurable
        configSvcKey = record.configSvcKey
    }
}

/// 模板分类元数据。
public struct TemplateCategory: Equatable, Sendable, Identifiable {
    public var id: TemplateCategoryID
    public var name: String
    public var sort: Int

    init(record: TemplateCategoryRecord) {
        id = TemplateCategoryID(rawValue: record.id) ?? .growthCard
        name = record.name
        sort = record.sort
    }
}

/// 占位符 `{{key}}` 替换；仅做字符串替换，不执行脚本。
enum TemplatePlaceholderResolver {
    static func resolve(_ text: String, placeholders: [TemplatePlaceholder]) -> String {
        placeholders.reduce(text) { current, placeholder in
            current.replacingOccurrences(of: "{{\(placeholder.key)}}", with: placeholder.value)
        }
    }
}
