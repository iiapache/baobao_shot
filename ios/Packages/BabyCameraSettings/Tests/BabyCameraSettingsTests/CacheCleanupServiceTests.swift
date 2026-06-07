import BabyCameraImageKit
import BabyCameraNetwork
import XCTest
@testable import BabyCameraSettings

final class CacheCleanupServiceTests: XCTestCase {
    private var tempThumbnailDirectory: URL!
    private var tempWebSocketDirectory: URL!

    override func setUpWithError() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CacheCleanupServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        tempThumbnailDirectory = root.appendingPathComponent("thumbnails", isDirectory: true)
        tempWebSocketDirectory = root.appendingPathComponent("ws", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let tempThumbnailDirectory {
            try? FileManager.default.removeItem(at: tempThumbnailDirectory.deletingLastPathComponent())
        }
        tempThumbnailDirectory = nil
        tempWebSocketDirectory = nil
    }

    func testClearAllCachesResetsSizeToZero() async throws {
        let cache = DiskLRUThumbnailCache(cacheDirectory: tempThumbnailDirectory)
        let key = ThumbnailCacheKey(filePath: "/tmp/photo.jpg", size: .small)
        await cache.store(Data(repeating: 0xAB, count: 256), for: key)

        try FileManager.default.createDirectory(at: tempWebSocketDirectory, withIntermediateDirectories: true)
        let wsFile = tempWebSocketDirectory.appendingPathComponent("feed.cache")
        try Data(repeating: 0xCD, count: 128).write(to: wsFile)

        let service = CacheCleanupService(
            thumbnailCache: LiveThumbnailCacheManaging(cache: cache),
            webSocketCacheDirectory: tempWebSocketDirectory
        )

        let before = await service.currentMetrics()
        XCTAssertGreaterThan(before.totalSizeBytes, 0)

        try await service.clearAllCaches()

        let after = await service.currentMetrics()
        XCTAssertEqual(after.totalSizeBytes, 0)
        XCTAssertEqual(after.thumbnailSizeBytes, 0)
        XCTAssertEqual(after.webSocketSizeBytes, 0)
    }

    func testClearAllCachesResetsHitRateMetrics() async throws {
        let cache = DiskLRUThumbnailCache(cacheDirectory: tempThumbnailDirectory)
        let sourcePath = try makeJPEGFile()
        _ = try await cache.loadThumbnail(filePath: sourcePath, size: .small)
        _ = try await cache.loadThumbnail(filePath: sourcePath, size: .small)

        let service = CacheCleanupService(
            thumbnailCache: LiveThumbnailCacheManaging(cache: cache),
            webSocketCacheDirectory: tempWebSocketDirectory
        )

        let before = await service.currentMetrics()
        XCTAssertGreaterThan(before.thumbnailMetrics.hits, 0)

        try await service.clearAllCaches()

        let after = await service.currentMetrics()
        XCTAssertEqual(after.thumbnailMetrics.hits, 0)
        XCTAssertEqual(after.thumbnailMetrics.misses, 0)
        XCTAssertEqual(after.thumbnailHitRate, 0)
    }

    func testCurrentMetricsReportsWebSocketAndThumbnailSizes() async throws {
        let cache = DiskLRUThumbnailCache(cacheDirectory: tempThumbnailDirectory)
        await cache.store(Data(repeating: 0x01, count: 200), for: ThumbnailCacheKey(filePath: "/a.jpg", size: .small))

        try FileManager.default.createDirectory(at: tempWebSocketDirectory, withIntermediateDirectories: true)
        try Data(repeating: 0x02, count: 300).write(to: tempWebSocketDirectory.appendingPathComponent("ai.cache"))

        let service = CacheCleanupService(
            thumbnailCache: LiveThumbnailCacheManaging(cache: cache),
            webSocketCacheDirectory: tempWebSocketDirectory
        )

        let metrics = await service.currentMetrics()
        XCTAssertGreaterThanOrEqual(metrics.thumbnailSizeBytes, 200)
        XCTAssertGreaterThanOrEqual(metrics.webSocketSizeBytes, 300)
        XCTAssertEqual(metrics.totalSizeBytes, metrics.thumbnailSizeBytes + metrics.webSocketSizeBytes)
    }

    private func makeJPEGFile() throws -> String {
        let codec = ImageCodec()
        let image = CacheCleanupTestImageFactory.makeSolidColorImage(
            width: 120,
            height: 90,
            color: .green
        )
        let jpegData = try codec.encode(image: image, format: .jpeg).data
        let url = tempThumbnailDirectory.deletingLastPathComponent().appendingPathComponent("source.jpg")
        try jpegData.write(to: url)
        return url.path
    }
}

#if canImport(UIKit)
import UIKit

private enum CacheCleanupTestImageFactory {
    static func makeSolidColorImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
#else
import AppKit

private enum CacheCleanupTestImageFactory {
    static func makeSolidColorImage(width: Int, height: Int, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        image.unlockFocus()
        return image
    }
}
#endif
