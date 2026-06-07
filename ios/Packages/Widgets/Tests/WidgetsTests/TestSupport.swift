import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import Widgets

final class TempWidgetAppGroupContainer: WidgetAppGroupContaining, @unchecked Sendable {
    let rootURL: URL

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func containerURL() throws -> URL {
        rootURL
    }
}

final class MockWidgetSnapshotStore: WidgetSnapshotStoring, @unchecked Sendable {
    private(set) var snapshot: WidgetSnapshot?
    private(set) var thumbnails: [String: Data] = [:]
    var writeSnapshotError: Error?
    var writeThumbnailError: Error?

    func writeSnapshot(_ snapshot: WidgetSnapshot) throws {
        if let writeSnapshotError { throw writeSnapshotError }
        self.snapshot = snapshot
    }

    func readSnapshot() throws -> WidgetSnapshot? {
        snapshot
    }

    func writeThumbnail(_ data: Data, photoId: String, size: WidgetThumbnailSize) throws -> String {
        if let writeThumbnailError { throw writeThumbnailError }
        let path = thumbnailRelativePath(photoId: photoId, size: size)
        thumbnails[path] = data
        return path
    }

    func thumbnailRelativePath(photoId: String, size: WidgetThumbnailSize) -> String {
        "\(WidgetAppGroupConfiguration.thumbnailsDirectoryName)/\(photoId)_\(size.fileSuffix).jpg"
    }
}

final class MockWidgetTimelineReloader: WidgetTimelineReloading, @unchecked Sendable {
    private(set) var reloadCount = 0

    func reloadAllTimelines() async {
        reloadCount += 1
    }
}

struct MockWidgetClock: WidgetClock {
    let fixedDate: Date

    func now() -> Date { fixedDate }
}

enum WidgetTestImageFactory {
    static func makeJPEGData(width: Int, height: Int, color: (CGFloat, CGFloat, CGFloat) = (0.9, 0.2, 0.2)) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        let r = UInt8((color.0 * 255).rounded())
        let g = UInt8((color.1 * 255).rounded())
        let b = UInt8((color.2 * 255).rounded())

        for row in 0..<height {
            for column in 0..<width {
                let index = row * bytesPerRow + column * bytesPerPixel
                pixels[index] = r
                pixels[index + 1] = g
                pixels[index + 2] = b
                pixels[index + 3] = 255
            }
        }

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            fatalError("Failed to create test image")
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            fatalError("Failed to create JPEG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            fatalError("Failed to finalize JPEG")
        }
        return data as Data
    }

    @discardableResult
    static func writeJPEGFile(
        width: Int,
        height: Int,
        to url: URL,
        color: (CGFloat, CGFloat, CGFloat) = (0.9, 0.2, 0.2)
    ) throws -> URL {
        let data = makeJPEGData(width: width, height: height, color: color)
        try data.write(to: url)
        return url
    }
}

func makeWidgetTestCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

func makeWidgetTestDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 12,
    calendar: Calendar = makeWidgetTestCalendar()
) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return calendar.date(from: components)!
}
