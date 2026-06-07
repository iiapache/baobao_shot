import Foundation

public protocol WidgetAppGroupContaining: Sendable {
    func containerURL() throws -> URL
}

public struct LiveWidgetAppGroupContainer: WidgetAppGroupContaining {
    public let groupIdentifier: String

    public init(groupIdentifier: String = WidgetAppGroupConfiguration.groupIdentifier) {
        self.groupIdentifier = groupIdentifier
    }

    public func containerURL() throws -> URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) else {
            throw WidgetError.appGroupUnavailable
        }
        return url
    }
}

public protocol WidgetSnapshotStoring: Sendable {
    func writeSnapshot(_ snapshot: WidgetSnapshot) throws
    func readSnapshot() throws -> WidgetSnapshot?
    func writeThumbnail(_ data: Data, photoId: String, size: WidgetThumbnailSize) throws -> String
    func thumbnailRelativePath(photoId: String, size: WidgetThumbnailSize) -> String
}

public struct WidgetAppGroupStore: WidgetSnapshotStoring {
    private let container: any WidgetAppGroupContaining
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        container: any WidgetAppGroupContaining = LiveWidgetAppGroupContainer(),
        fileManager: FileManager = .default
    ) {
        self.container = container
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func thumbnailRelativePath(photoId: String, size: WidgetThumbnailSize) -> String {
        "\(WidgetAppGroupConfiguration.thumbnailsDirectoryName)/\(photoId)_\(size.fileSuffix).jpg"
    }

    public func writeThumbnail(
        _ data: Data,
        photoId: String,
        size: WidgetThumbnailSize
    ) throws -> String {
        let root = try container.containerURL()
        let thumbnailsDirectory = root.appendingPathComponent(
            WidgetAppGroupConfiguration.thumbnailsDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

        let relativePath = thumbnailRelativePath(photoId: photoId, size: size)
        let destination = root.appendingPathComponent(relativePath)
        try data.write(to: destination, options: .atomic)
        return relativePath
    }

    public func writeSnapshot(_ snapshot: WidgetSnapshot) throws {
        let root = try container.containerURL()
        let destination = root.appendingPathComponent(WidgetAppGroupConfiguration.snapshotFileName)
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: destination, options: .atomic)
        } catch {
            throw WidgetError.snapshotWriteFailed
        }
    }

    public func readSnapshot() throws -> WidgetSnapshot? {
        let root = try container.containerURL()
        let source = root.appendingPathComponent(WidgetAppGroupConfiguration.snapshotFileName)
        guard fileManager.fileExists(atPath: source.path) else {
            return nil
        }
        let data = try Data(contentsOf: source)
        return try decoder.decode(WidgetSnapshot.self, from: data)
    }
}
