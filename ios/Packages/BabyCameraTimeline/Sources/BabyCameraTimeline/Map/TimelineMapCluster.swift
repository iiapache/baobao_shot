import CoreLocation
import Foundation

/// 地图上聚合后的 POI 簇（单点或多张照片）。
public struct TimelineMapCluster: Equatable, Identifiable, Sendable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let photos: [TimelinePhotoItem]

    public var count: Int { photos.count }
    public var isCluster: Bool { photos.count > 1 }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(id: String, latitude: Double, longitude: Double, photos: [TimelinePhotoItem]) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.photos = photos
    }
}
