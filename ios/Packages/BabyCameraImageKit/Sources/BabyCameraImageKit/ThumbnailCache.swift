import Foundation

/// 缩略图缓存键（文件路径 + 尺寸档位）。
public struct ThumbnailCacheKey: Hashable, Sendable {
    public let filePath: String
    public let size: ThumbnailSize

    public init(filePath: String, size: ThumbnailSize) {
        self.filePath = filePath
        self.size = size
    }
}

/// 缩略图缓存协议。T2.21 磁盘 LRU（7 天 / 1GB 上限）。
public protocol ThumbnailCaching: Sendable {
    func cachedData(for key: ThumbnailCacheKey) async -> Data?
    func store(_ data: Data, for key: ThumbnailCacheKey) async
    func loadThumbnail(filePath: String, size: ThumbnailSize) async throws -> Data
}

/// 缩略图缓存命中率统计。
public struct ThumbnailCacheMetrics: Sendable, Equatable {
    public let hits: Int
    public let misses: Int

    public init(hits: Int, misses: Int) {
        self.hits = hits
        self.misses = misses
    }

    public var totalRequests: Int { hits + misses }

    public var hitRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(hits) / Double(totalRequests)
    }
}

actor ThumbnailCacheMetricsCollector {
    private var hits = 0
    private var misses = 0

    func recordHit() {
        hits += 1
    }

    func recordMiss() {
        misses += 1
    }

    func snapshot() -> ThumbnailCacheMetrics {
        ThumbnailCacheMetrics(hits: hits, misses: misses)
    }

    func reset() {
        hits = 0
        misses = 0
    }
}

/// 磁盘 LRU + 内存热缓存 + 按需生成（T2.21）。
public struct DiskLRUThumbnailCache: ThumbnailCaching {
    private let diskStore: DiskThumbnailLRUStore
    private let memoryCache: MemoryThumbnailStore
    private let generator: any ThumbnailGenerating
    private let metrics: ThumbnailCacheMetricsCollector

    public init(
        configuration: ThumbnailCacheConfiguration = .default,
        generator: any ThumbnailGenerating = ThumbnailGenerator(),
        cacheDirectory: URL? = nil,
        memoryCache: MemoryThumbnailStore = MemoryThumbnailStore()
    ) {
        let directory = cacheDirectory ?? Self.defaultCacheDirectory()
        self.diskStore = DiskThumbnailLRUStore(directory: directory, configuration: configuration)
        self.generator = generator
        self.memoryCache = memoryCache
        self.metrics = ThumbnailCacheMetricsCollector()
    }

    public func cachedData(for key: ThumbnailCacheKey) async -> Data? {
        if let cached = await memoryCache.value(for: key) {
            return cached
        }

        if let cached = await diskStore.data(for: key) {
            await memoryCache.set(cached, for: key)
            return cached
        }

        return nil
    }

    public func store(_ data: Data, for key: ThumbnailCacheKey) async {
        await memoryCache.set(data, for: key)
        await diskStore.store(data, for: key)
    }

    public func loadThumbnail(filePath: String, size: ThumbnailSize) async throws -> Data {
        let key = ThumbnailCacheKey(filePath: filePath, size: size)

        if let cached = await memoryCache.value(for: key) {
            await recordHit(size: size)
            return cached
        }

        if let cached = await diskStore.data(for: key) {
            await memoryCache.set(cached, for: key)
            await recordHit(size: size)
            return cached
        }

        await recordMiss(size: size)

        let fileURL = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: fileURL)
        let encoded = try generator.generateData(from: data, size: size, format: .jpeg, quality: 0.85)
        await store(encoded.data, for: key)
        return encoded.data
    }

    public func metrics() async -> ThumbnailCacheMetrics {
        await metrics.snapshot()
    }

    public func resetMetrics() async {
        await metrics.reset()
    }

    /// 磁盘 + 内存缓存总占用（字节）。
    public func cacheSizeBytes() async -> Int64 {
        let diskBytes = await diskStore.totalStoredBytes()
        let memoryBytes = await memoryCache.totalStoredBytes()
        return diskBytes + memoryBytes
    }

    /// 清空磁盘与内存缓存，并重置命中率统计。
    public func clearAll() async {
        await diskStore.removeAll()
        await memoryCache.removeAll()
        await resetMetrics()
    }

    private func recordHit(size: ThumbnailSize) async {
        await metrics.recordHit()
        ImageKitAnalytics.track(
            ImageKitAnalytics.Event.thumbnailCacheHit,
            parameters: ["size": String(size.rawValue)]
        )
    }

    private func recordMiss(size: ThumbnailSize) async {
        await metrics.recordMiss()
        ImageKitAnalytics.track(
            ImageKitAnalytics.Event.thumbnailCacheMiss,
            parameters: ["size": String(size.rawValue)]
        )
    }

    private static func defaultCacheDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("BabyCameraImageKit/thumbnails", isDirectory: true)
    }
}

/// 按需生成 + 进程内内存缓存（测试 / 轻量场景）。
public struct GeneratingThumbnailCache: ThumbnailCaching {
    private let generator: any ThumbnailGenerating
    private let memoryCache: MemoryThumbnailStore

    public init(
        generator: any ThumbnailGenerating = ThumbnailGenerator(),
        memoryCache: MemoryThumbnailStore = MemoryThumbnailStore()
    ) {
        self.generator = generator
        self.memoryCache = memoryCache
    }

    public func cachedData(for key: ThumbnailCacheKey) async -> Data? {
        await memoryCache.value(for: key)
    }

    public func store(_ data: Data, for key: ThumbnailCacheKey) async {
        await memoryCache.set(data, for: key)
    }

    public func loadThumbnail(filePath: String, size: ThumbnailSize) async throws -> Data {
        let key = ThumbnailCacheKey(filePath: filePath, size: size)
        if let cached = await memoryCache.value(for: key) {
            return cached
        }

        let fileURL = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: fileURL)
        let encoded = try generator.generateData(from: data, size: size, format: .jpeg, quality: 0.85)
        await memoryCache.set(encoded.data, for: key)
        return encoded.data
    }
}

/// 线程安全的进程内缩略图存储。
public actor MemoryThumbnailStore {
    private var storage: [ThumbnailCacheKey: Data] = [:]

    public init() {}

    public func value(for key: ThumbnailCacheKey) -> Data? {
        storage[key]
    }

    public func set(_ data: Data, for key: ThumbnailCacheKey) {
        storage[key] = data
    }

    public func removeAll() {
        storage.removeAll()
    }

    public func totalStoredBytes() -> Int64 {
        storage.values.reduce(0) { $0 + Int64($1.count) }
    }
}
