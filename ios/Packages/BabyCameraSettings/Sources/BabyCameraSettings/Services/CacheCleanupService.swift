import BabyCameraImageKit
import BabyCameraNetwork
import Foundation

public struct CacheCleanupMetrics: Equatable, Sendable {
    public let totalSizeBytes: Int64
    public let thumbnailSizeBytes: Int64
    public let webSocketSizeBytes: Int64
    public let thumbnailMetrics: ThumbnailCacheMetrics

    public init(
        totalSizeBytes: Int64,
        thumbnailSizeBytes: Int64,
        webSocketSizeBytes: Int64,
        thumbnailMetrics: ThumbnailCacheMetrics
    ) {
        self.totalSizeBytes = totalSizeBytes
        self.thumbnailSizeBytes = thumbnailSizeBytes
        self.webSocketSizeBytes = webSocketSizeBytes
        self.thumbnailMetrics = thumbnailMetrics
    }

    public var thumbnailHitRate: Double {
        thumbnailMetrics.hitRate
    }
}

/// 清理缩略图与 WebSocket 本地缓存（T6.12）。
public struct CacheCleanupService: Sendable {
    private let thumbnailCache: any ThumbnailCacheManaging
    private let webSocketCacheDirectory: URL
    private let fileManager: FileManager

    public init(
        thumbnailCache: any ThumbnailCacheManaging,
        webSocketCacheDirectory: URL = NetworkLocalCachePaths.webSocketCacheDirectory(),
        fileManager: FileManager = .default
    ) {
        self.thumbnailCache = thumbnailCache
        self.webSocketCacheDirectory = webSocketCacheDirectory
        self.fileManager = fileManager
    }

    public func currentMetrics() async -> CacheCleanupMetrics {
        let thumbnailSize = await thumbnailCache.cacheSizeBytes()
        let webSocketSize = NetworkLocalCachePaths.directorySizeBytes(
            at: webSocketCacheDirectory,
            fileManager: fileManager
        )
        let thumbnailMetrics = await thumbnailCache.metrics()
        return CacheCleanupMetrics(
            totalSizeBytes: thumbnailSize + webSocketSize,
            thumbnailSizeBytes: thumbnailSize,
            webSocketSizeBytes: webSocketSize,
            thumbnailMetrics: thumbnailMetrics
        )
    }

    public func clearAllCaches() async throws {
        await thumbnailCache.clearAll()
        try NetworkLocalCachePaths.clearDirectory(
            at: webSocketCacheDirectory,
            fileManager: fileManager
        )
    }
}
