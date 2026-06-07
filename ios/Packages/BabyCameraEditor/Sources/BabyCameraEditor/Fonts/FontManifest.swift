import Foundation

/// design-assets/fonts/manifest.json 解码模型。
struct FontManifest: Codable, Sendable {
    var schemaVersion: String
    var fonts: [FontRecord]
}

struct FontRecord: Codable, Sendable {
    var id: String
    var name: String
    var family: String
    var postScriptName: String
    var file: String
    var licenseFile: String
    var vendor: String
    var licenseType: String
    var commercial: Bool
    var usage: [String]
    var styles: [String]
    var languageSupport: [String]
    var description: String?
    var odrTag: String?
}

/// 运行时字体条目，供 TextStep UI 与授权清单对齐（T0.11）。
public struct FontAsset: Equatable, Sendable, Identifiable {
    public var id: String
    public var displayName: String
    public var family: String
    public var postScriptName: String
    public var filePath: String
    public var licenseFile: String
    public var vendor: String
    public var licenseType: String
    public var commercial: Bool
    public var usage: [String]
    public var styles: [String]
    public var languageSupport: [String]
    public var description: String
    public var odrTag: String

    public var supportsEditorText: Bool {
        usage.contains("editor_text")
    }

    init(record: FontRecord) {
        id = record.id
        displayName = record.name
        family = record.family
        postScriptName = record.postScriptName
        filePath = record.file
        licenseFile = record.licenseFile
        vendor = record.vendor
        licenseType = record.licenseType
        commercial = record.commercial
        usage = record.usage
        styles = record.styles
        languageSupport = record.languageSupport
        description = record.description ?? ""
        odrTag = record.odrTag ?? "editor-fonts"
    }
}
