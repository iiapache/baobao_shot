import Foundation

enum DesignAssetManifestLoader {
    enum Error: Swift.Error {
        case resourceNotFound(String)
        case decodeFailed(String, underlying: Swift.Error)
    }

    static func load<T: Decodable>(_ type: T.Type, resource name: String) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw Error.resourceNotFound(name)
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw Error.decodeFailed(name, underlying: error)
        }
    }
}
