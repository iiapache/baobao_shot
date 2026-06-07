import CoreImage
import Foundation

/// 编辑器模板库（T2.14：≥ 12 套，成长卡片 / 百天卡 / 周岁卡，对接 design-assets/templates/manifest.json）。
public enum TemplateCatalog {
    public static let minimumTemplateCount = 12
    public static let manifestResourceName = TemplateManifestLoader.catalogResourceName

    /// 宿主注入 config-svc 远端 manifest 提供者。
    public static var remoteProvider: (any RemoteTemplateProvider)?

    private static var catalogManifest: TemplateCatalogManifest = loadCatalogManifest()
    private static var detailCache: [String: TemplateDetailManifest] = [:]

    public static var categories: [TemplateCategory] {
        catalogManifest.categories
            .map(TemplateCategory.init)
            .sorted { $0.sort < $1.sort }
    }

    public static var templates: [TemplateAsset] {
        catalogManifest.templates.map(TemplateAsset.init)
    }

    private static var templatesByID: [String: TemplateAsset] {
        Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
    }

    private static var templatesByCategory: [TemplateCategoryID: [TemplateAsset]] {
        Dictionary(grouping: templates, by: \.category)
    }

    public static func template(for id: String) -> TemplateAsset? {
        templatesByID[id]
    }

    public static func templates(in category: TemplateCategoryID) -> [TemplateAsset] {
        templatesByCategory[category] ?? []
    }

    public static var satisfiesMinimumCount: Bool {
        templates.count >= minimumTemplateCount
    }

    public static var hasAllCategoriesRepresented: Bool {
        TemplateCategoryID.allCases.allSatisfy { !(templatesByCategory[$0] ?? []).isEmpty }
    }

    /// 加载单套模板 detail manifest（带内存缓存）。
    public static func detailManifest(for templateID: String) throws -> TemplateDetailManifest {
        if let cached = detailCache[templateID] {
            return cached
        }
        guard let asset = template(for: templateID) else {
            throw TemplateManifestLoader.Error.resourceNotFound(templateID)
        }
        let detail = try TemplateManifestLoader.loadDetailFromBundle(manifestPath: asset.manifestPath)
        detailCache[templateID] = detail
        return detail
    }

    /// 从 manifest 构建 `TemplateStep`（含 nestedSteps）。
    public static func makeTemplateStep(
        templateID: String,
        placeholders: [TemplatePlaceholder] = []
    ) throws -> TemplateStep {
        let detail = try detailManifest(for: templateID)
        return TemplateStep(
            templateID: templateID,
            placeholders: placeholders,
            nestedSteps: buildNestedSteps(from: detail, placeholders: placeholders)
        )
    }

    /// 从远端 config-svc 拉取并合并 catalog / 单套 manifest 覆盖。
    public static func refreshFromRemote() async throws {
        guard let provider = remoteProvider else { return }

        if let catalogData = try await provider.fetchCatalogManifest() {
            let remoteCatalog = try TemplateManifestLoader.loadCatalog(from: catalogData)
            catalogManifest = TemplateManifestLoader.mergeCatalog(local: catalogManifest, remote: remoteCatalog)
        }

        for asset in catalogManifest.templates where asset.remoteConfigurable {
            guard let data = try await provider.fetchTemplateManifest(configSvcKey: asset.configSvcKey) else {
                continue
            }
            let detail = try TemplateManifestLoader.loadDetail(from: data)
            detailCache[asset.id] = detail
        }
    }

    /// 单测重置缓存与 catalog。
    static func resetForTesting(
        catalog: TemplateCatalogManifest? = nil,
        details: [String: TemplateDetailManifest] = [:]
    ) {
        if let catalog {
            catalogManifest = catalog
        } else {
            catalogManifest = loadCatalogManifest()
        }
        detailCache = details
    }

    static func buildNestedSteps(
        from detail: TemplateDetailManifest,
        placeholders: [TemplatePlaceholder]
    ) -> [AnyEditStep] {
        var result = detail.steps

        let textSteps = detail.placeholders
            .filter { $0.type == "text" }
            .map { record -> AnyEditStep in
                let resolvedText = TemplatePlaceholderResolver.resolve(
                    record.defaultValue ?? "",
                    placeholders: placeholders
                )
                let fontID = record.fontId ?? FontCatalog.defaultFontID
                let rect = record.rect
                return .text(TextStep(
                    text: resolvedText,
                    fontName: FontCatalog.postScriptName(for: fontID),
                    fontID: fontID,
                    fontSize: fontSize(for: record, canvas: detail.canvas),
                    centerX: rect.x + rect.width / 2,
                    centerY: rect.y + rect.height / 2
                ))
            }
        result.append(contentsOf: textSteps)

        let stickerSteps = detail.resources.stickers.map { stickerID in
            AnyEditStep.sticker(StickerStep(resourceID: stickerID))
        }
        result.append(contentsOf: stickerSteps)

        return result
    }

    private static func loadCatalogManifest() -> TemplateCatalogManifest {
        do {
            return try TemplateManifestLoader.loadCatalogFromBundle()
        } catch {
            assertionFailure("Template catalog manifest load failed: \(error)")
            return TemplateCatalogManifest(schemaVersion: "0", categories: [], templates: [])
        }
    }

    private static func fontSize(for placeholder: TemplatePlaceholderRecord, canvas: TemplateCanvasRecord) -> Double {
        Double(canvas.height) * placeholder.rect.height * 0.75
    }
}
