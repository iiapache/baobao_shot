import Foundation

/// config-svc 远端模板 manifest 下发协议；仅 JSON Data，不下发可执行代码。
public protocol RemoteTemplateProvider: Sendable {
    func fetchCatalogManifest() async throws -> Data?
    func fetchTemplateManifest(configSvcKey: String) async throws -> Data?
}

/// 模板 manifest 加载器：Bundle 本地 + 可选远端覆盖。
enum TemplateManifestLoader {
    enum Error: Swift.Error, Equatable {
        case resourceNotFound(String)
        case decodeFailed(String)
        case invalidManifestPath(String)
        case unsupportedEditorStepType(String)
    }

    static let catalogResourceName = "templates-manifest"
    static let templatesBundleSubdirectory = "Templates"

    static func loadCatalog(from data: Data) throws -> TemplateCatalogManifest {
        do {
            return try JSONDecoder().decode(TemplateCatalogManifest.self, from: data)
        } catch {
            throw Error.decodeFailed("catalog")
        }
    }

    static func loadDetail(from data: Data) throws -> TemplateDetailManifest {
        let manifest: TemplateDetailManifest
        do {
            manifest = try JSONDecoder().decode(TemplateDetailManifest.self, from: data)
        } catch {
            throw Error.decodeFailed("detail")
        }
        try validateDetail(manifest)
        return manifest
    }

    static func loadCatalogFromBundle(resource: String = catalogResourceName) throws -> TemplateCatalogManifest {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json") else {
            throw Error.resourceNotFound(resource)
        }
        let data = try Data(contentsOf: url)
        return try loadCatalog(from: data)
    }

    static func loadDetailFromBundle(manifestPath: String) throws -> TemplateDetailManifest {
        guard let url = bundleURL(forManifestPath: manifestPath) else {
            throw Error.resourceNotFound(manifestPath)
        }
        let data = try Data(contentsOf: url)
        return try loadDetail(from: data)
    }

    /// 合并远端 catalog；远端条目按 `id` 覆盖本地同 id 模板摘要。
    static func mergeCatalog(
        local: TemplateCatalogManifest,
        remote: TemplateCatalogManifest
    ) -> TemplateCatalogManifest {
        var merged = local
        var indexByID = Dictionary(uniqueKeysWithValues: merged.templates.enumerated().map { ($1.id, $0) })

        for remoteTemplate in remote.templates {
            if let index = indexByID[remoteTemplate.id] {
                merged.templates[index] = remoteTemplate
            } else {
                indexByID[remoteTemplate.id] = merged.templates.count
                merged.templates.append(remoteTemplate)
            }
        }

        for remoteCategory in remote.categories {
            if !merged.categories.contains(where: { $0.id == remoteCategory.id }) {
                merged.categories.append(remoteCategory)
            }
        }

        if !remote.schemaVersion.isEmpty {
            merged.schemaVersion = remote.schemaVersion
        }
        return merged
    }

    static func bundleURL(forManifestPath path: String) -> URL? {
        let relative: String
        if path.hasPrefix("templates/") {
            relative = String(path.dropFirst("templates/".count))
        } else {
            relative = path
        }

        let directory = (relative as NSString).deletingLastPathComponent
        let filename = (relative as NSString).lastPathComponent
        let basename = (filename as NSString).deletingPathExtension
        let subdirectory = directory.isEmpty
            ? templatesBundleSubdirectory
            : "\(templatesBundleSubdirectory)/\(directory)"

        return Bundle.module.url(
            forResource: basename,
            withExtension: "json",
            subdirectory: subdirectory
        )
    }

    private static func validateDetail(_ manifest: TemplateDetailManifest) throws {
        if let stepType = manifest.editorStepType, stepType != "TemplateStep" {
            throw Error.unsupportedEditorStepType(stepType)
        }
    }
}
