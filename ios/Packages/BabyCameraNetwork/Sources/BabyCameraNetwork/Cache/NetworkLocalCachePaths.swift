import Foundation

/// BabyCameraNetwork 本地缓存目录约定（T6.12 WebSocket 缓存清理）。
public enum NetworkLocalCachePaths {
    public static let webSocketCacheComponent = "BabyCameraNetwork/ws"

    public static func webSocketCacheDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent(webSocketCacheComponent, isDirectory: true)
    }

    public static func directorySizeBytes(
        at url: URL,
        fileManager: FileManager = .default
    ) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                values.isRegularFile == true,
                let size = values.fileSize
            else {
                continue
            }
            total += Int64(size)
        }
        return total
    }

    public static func clearDirectory(
        at url: URL,
        fileManager: FileManager = .default
    ) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
