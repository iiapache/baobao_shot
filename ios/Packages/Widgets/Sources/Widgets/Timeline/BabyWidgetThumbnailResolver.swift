import Foundation

public enum BabyWidgetThumbnailResolver {
    public static func resolveURL(
        relativePath: String?,
        containerURL: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let relativePath, !relativePath.isEmpty else {
            return nil
        }

        let fileURL = containerURL.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return fileURL
    }
}
