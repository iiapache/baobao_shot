import Foundation

enum MilestoneManifestLoader {
    static let catalogResourceName = "milestones-manifest"

    enum Error: Swift.Error, Equatable {
        case resourceNotFound(String)
        case decodeFailed(String)
    }

    static func loadCatalogFromBundle(bundle: Bundle = .module) throws -> MilestoneCatalogManifest {
        guard let url = bundle.url(forResource: catalogResourceName, withExtension: "json") else {
            throw Error.resourceNotFound(catalogResourceName)
        }
        let data = try Data(contentsOf: url)
        return try loadCatalog(from: data)
    }

    static func loadCatalog(from data: Data) throws -> MilestoneCatalogManifest {
        do {
            return try JSONDecoder().decode(MilestoneCatalogManifest.self, from: data)
        } catch {
            throw Error.decodeFailed(String(describing: error))
        }
    }
}
