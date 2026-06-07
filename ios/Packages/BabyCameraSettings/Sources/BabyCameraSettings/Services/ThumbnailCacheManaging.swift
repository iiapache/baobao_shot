import BabyCameraImageKit
import Foundation

/// 缩略图缓存管理抽象，便于测试注入。
public protocol ThumbnailCacheManaging: Sendable {
    func metrics() async -> ThumbnailCacheMetrics
    func cacheSizeBytes() async -> Int64
    func clearAll() async
}

/// 基于 `DiskLRUThumbnailCache` 的生产实现。
public struct LiveThumbnailCacheManaging: ThumbnailCacheManaging {
    private let cache: DiskLRUThumbnailCache

    public init(cache: DiskLRUThumbnailCache = DiskLRUThumbnailCache()) {
        self.cache = cache
    }

    public func metrics() async -> ThumbnailCacheMetrics {
        await cache.metrics()
    }

    public func cacheSizeBytes() async -> Int64 {
        await cache.cacheSizeBytes()
    }

    public func clearAll() async {
        await cache.clearAll()
    }
}
