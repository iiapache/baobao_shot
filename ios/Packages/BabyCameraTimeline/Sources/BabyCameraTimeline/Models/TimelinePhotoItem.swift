import CoreLocation
import Database
import Foundation

/// 时间线中的单张照片条目（UI 层轻量模型）。
public struct TimelinePhotoItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let takenAt: Int64
    public let filePath: String
    public let latitude: Double?
    public let longitude: Double?

    public init(
        id: String,
        takenAt: Int64,
        filePath: String,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.takenAt = takenAt
        self.filePath = filePath
        self.latitude = latitude
        self.longitude = longitude
    }

    /// 是否包含有效 GPS 坐标。
    public var hasGPS: Bool {
        latitude != nil && longitude != nil
    }

    public var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension TimelinePhotoItem {
    init(photo: PhotoRecord) {
        id = photo.id
        takenAt = photo.takenAt
        filePath = photo.filePath
        latitude = photo.lat
        longitude = photo.lng
    }
}
