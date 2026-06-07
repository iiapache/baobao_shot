import Foundation
import ImageIO

/// 从图片文件解析的 EXIF / GPS 元数据。
public struct EXIFMetadata: Equatable, Sendable {
    /// EXIF `DateTimeOriginal` 解析后的拍摄时间。
    public let dateTimeOriginal: Date?
    public let latitude: Double?
    public let longitude: Double?

    public init(
        dateTimeOriginal: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.dateTimeOriginal = dateTimeOriginal
        self.latitude = latitude
        self.longitude = longitude
    }

    public var hasDateTimeOriginal: Bool {
        dateTimeOriginal != nil
    }
}

/// EXIF 读取协议，便于单测注入 mock。
public protocol EXIFReading: Sendable {
    func read(from url: URL) throws -> EXIFMetadata
}

/// 基于 ImageIO 的 EXIF 读取实现。
public struct EXIFReader: EXIFReading {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func read(from url: URL) throws -> EXIFMetadata {
        guard fileManager.fileExists(atPath: url.path) else {
            throw ImageKitError.invalidData
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageKitError.decodeFailed
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return EXIFMetadata()
        }

        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let dateTimeOriginal = Self.parseDateTimeOriginal(
            exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String
        )

        let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        let latitude = Self.parseGPSCoordinate(
            gps?[kCGImagePropertyGPSLatitude as String],
            ref: gps?[kCGImagePropertyGPSLatitudeRef as String] as? String
        )
        let longitude = Self.parseGPSCoordinate(
            gps?[kCGImagePropertyGPSLongitude as String],
            ref: gps?[kCGImagePropertyGPSLongitudeRef as String] as? String
        )

        return EXIFMetadata(
            dateTimeOriginal: dateTimeOriginal,
            latitude: latitude,
            longitude: longitude
        )
    }

    // MARK: - Parsing

    /// EXIF 日期格式：`yyyy:MM:dd HH:mm:ss`（本地时区解释，与系统相册一致）。
    static func parseDateTimeOriginal(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: value)
    }

    static func exifDateTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private static func parseGPSCoordinate(_ value: Any?, ref: String?) -> Double? {
        guard let value else { return nil }

        let degrees: Double
        if let number = value as? NSNumber {
            degrees = number.doubleValue
        } else if let array = value as? [Any], array.count >= 3 {
            let d = (array[0] as? NSNumber)?.doubleValue ?? 0
            let m = (array[1] as? NSNumber)?.doubleValue ?? 0
            let s = (array[2] as? NSNumber)?.doubleValue ?? 0
            degrees = d + m / 60.0 + s / 3600.0
        } else {
            return nil
        }

        guard let ref, !ref.isEmpty else { return degrees }
        if ref == "S" || ref == "W" {
            return -degrees
        }
        return degrees
    }
}
