import CoreGraphics
import XCTest
@testable import BabyCameraImageKit

final class ThumbnailCacheTests: XCTestCase {
    private var tempDirectory: URL!
    private var trackedEvents: [(String, [String: String])] = []
    private var previousTrackHandler: ImageKitAnalytics.TrackHandler!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThumbnailCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        previousTrackHandler = ImageKitAnalytics.trackHandler
        trackedEvents = []
        ImageKitAnalytics.trackHandler = { [weak self] event, parameters in
            self?.trackedEvents.append((event, parameters))
        }
    }

    override func tearDownWithError() throws {
        ImageKitAnalytics.trackHandler = previousTrackHandler
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testSmallAndMediumSizesAreCachedSeparately() async throws {
        let sourcePath = try makeSourceImage(width: 2400, height: 1800)
        let cache = makeCache(maxTotalBytes: 10 * 1024 * 1024)

        let small = try await cache.loadThumbnail(filePath: sourcePath, size: .small)
        let medium = try await cache.loadThumbnail(filePath: sourcePath, size: .medium)

        XCTAssertFalse(small.isEmpty)
        XCTAssertFalse(medium.isEmpty)
        XCTAssertNotEqual(small.count, medium.count)

        let store = DiskThumbnailLRUStore(
            directory: tempDirectory,
            configuration: .init(maxTotalBytes: 10 * 1024 * 1024)
        )
        XCTAssertTrue(await store.containsEntry(for: ThumbnailCacheKey(filePath: sourcePath, size: .small)))
        XCTAssertTrue(await store.containsEntry(for: ThumbnailCacheKey(filePath: sourcePath, size: .medium)))
    }

    func testLRUEvictionRemovesLeastRecentlyUsedEntry() async throws {
        let config = ThumbnailCacheConfiguration(maxTotalBytes: 900)
        let store = DiskThumbnailLRUStore(directory: tempDirectory, configuration: config)

        let oldestKey = ThumbnailCacheKey(filePath: "/photos/oldest.jpg", size: .small)
        let middleKey = ThumbnailCacheKey(filePath: "/photos/middle.jpg", size: .small)
        let newestKey = ThumbnailCacheKey(filePath: "/photos/newest.jpg", size: .small)

        await store.store(Data(repeating: 0x01, count: 300), for: oldestKey)
        await store.store(Data(repeating: 0x02, count: 300), for: middleKey)
        _ = await store.data(for: middleKey)
        await store.store(Data(repeating: 0x03, count: 400), for: newestKey)

        XCTAssertFalse(await store.containsEntry(for: oldestKey))
        XCTAssertTrue(await store.containsEntry(for: middleKey))
        XCTAssertTrue(await store.containsEntry(for: newestKey))
        XCTAssertLessThanOrEqual(await store.totalStoredBytes(), config.maxTotalBytes)
    }

    func testExpiredEntryIsRemovedOnAccess() async throws {
        let dateProvider = TestDateProvider(startingAt: Date(timeIntervalSince1970: 1_700_000_000))
        let config = ThumbnailCacheConfiguration(
            maxTotalBytes: 1024 * 1024,
            expirationInterval: 7 * 24 * 60 * 60,
            dateProvider: { dateProvider.now() }
        )
        let store = DiskThumbnailLRUStore(directory: tempDirectory, configuration: config)
        let key = ThumbnailCacheKey(filePath: "/photos/expired.jpg", size: .small)

        await store.store(Data(repeating: 0xAB, count: 128), for: key)
        XCTAssertTrue(await store.containsEntry(for: key))

        dateProvider.advance(by: 8 * 24 * 60 * 60)
        let loaded = await store.data(for: key)
        XCTAssertNil(loaded)
        XCTAssertFalse(await store.containsEntry(for: key))
    }

    func testSizeCapEvictsUntilWithinLimit() async throws {
        let config = ThumbnailCacheConfiguration(maxTotalBytes: 500)
        let store = DiskThumbnailLRUStore(directory: tempDirectory, configuration: config)

        for index in 0..<5 {
            let key = ThumbnailCacheKey(filePath: "/photos/item-\(index).jpg", size: .small)
            await store.store(Data(repeating: UInt8(index), count: 200), for: key)
        }

        XCTAssertLessThanOrEqual(await store.totalStoredBytes(), config.maxTotalBytes)
        XCTAssertEqual(await store.entryCount(), 2)
    }

    func testDefaultConfigurationMatchesSpec() {
        XCTAssertEqual(ThumbnailCacheConfiguration.defaultMaxTotalBytes, 1_073_741_824)
        XCTAssertEqual(ThumbnailCacheConfiguration.defaultExpirationInterval, 7 * 24 * 60 * 60)
        XCTAssertEqual(ThumbnailSize.small.rawValue, 256)
        XCTAssertEqual(ThumbnailSize.medium.rawValue, 1024)
    }

    func testHitRateMetricsAndAnalyticsHook() async throws {
        let sourcePath = try makeSourceImage(width: 1600, height: 1200)
        let cache = makeCache(maxTotalBytes: 5 * 1024 * 1024)
        await cache.resetMetrics()

        _ = try await cache.loadThumbnail(filePath: sourcePath, size: .small)
        _ = try await cache.loadThumbnail(filePath: sourcePath, size: .small)
        _ = try await cache.loadThumbnail(filePath: sourcePath, size: .medium)
        _ = try await cache.loadThumbnail(filePath: sourcePath, size: .medium)

        let metrics = await cache.metrics()
        XCTAssertEqual(metrics.hits, 2)
        XCTAssertEqual(metrics.misses, 2)
        XCTAssertEqual(metrics.hitRate, 0.5, accuracy: 0.001)

        let hitEvents = trackedEvents.filter { $0.0 == ImageKitAnalytics.Event.thumbnailCacheHit }
        let missEvents = trackedEvents.filter { $0.0 == ImageKitAnalytics.Event.thumbnailCacheMiss }
        XCTAssertEqual(hitEvents.count, 2)
        XCTAssertEqual(missEvents.count, 2)
        XCTAssertEqual(Set(hitEvents.map(\.1["size"])), Set(["256", "1024"]))
    }

    func testDiskCacheSurvivesReload() async throws {
        let sourcePath = try makeSourceImage(width: 2000, height: 1500)
        let config = ThumbnailCacheConfiguration(maxTotalBytes: 5 * 1024 * 1024)

        let firstCache = DiskLRUThumbnailCache(configuration: config, cacheDirectory: tempDirectory)
        let generated = try await firstCache.loadThumbnail(filePath: sourcePath, size: .small)

        let reloadedCache = DiskLRUThumbnailCache(
            configuration: config,
            cacheDirectory: tempDirectory,
            memoryCache: MemoryThumbnailStore()
        )
        let cached = try await reloadedCache.loadThumbnail(filePath: sourcePath, size: .small)

        XCTAssertEqual(generated, cached)
        let metrics = await reloadedCache.metrics()
        XCTAssertEqual(metrics.hits, 1)
        XCTAssertEqual(metrics.misses, 0)
    }

    // MARK: - Helpers

    private func makeCache(maxTotalBytes: Int64) -> DiskLRUThumbnailCache {
        DiskLRUThumbnailCache(
            configuration: .init(maxTotalBytes: maxTotalBytes),
            cacheDirectory: tempDirectory,
            memoryCache: MemoryThumbnailStore()
        )
    }

    private func makeSourceImage(width: Int, height: Int) throws -> String {
        let codec = ImageCodec()
        let image = ThumbnailCacheTestImageFactory.makeSolidColorImage(
            width: width,
            height: height,
            color: .blue
        )
        let jpegData = try codec.encode(image: image, format: .jpeg).data
        let fileURL = tempDirectory.appendingPathComponent("source-\(UUID().uuidString).jpg")
        try jpegData.write(to: fileURL)
        return fileURL.path
    }
}

private final class TestDateProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var currentDate: Date

    init(startingAt date: Date) {
        currentDate = date
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return currentDate
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        currentDate = currentDate.addingTimeInterval(interval)
    }
}

private enum ThumbnailCacheTestImageFactory {
    enum Color {
        case blue
    }

    static func makeSolidColorImage(width: Int, height: Int, color: Color) -> CGImage {
        let components: [CGFloat] = [0, 0, 1, 1]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let cgColor = CGColor(colorSpace: colorSpace, components: components)!
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
