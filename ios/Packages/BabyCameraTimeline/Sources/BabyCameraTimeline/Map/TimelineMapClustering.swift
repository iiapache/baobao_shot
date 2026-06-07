import CoreLocation
import Foundation

/// 相近坐标 POI 聚合（纯逻辑，可单测）。
public enum TimelineMapClustering {
    /// 默认聚合半径（米）。
    public static let defaultClusterRadiusMeters: Double = 50

    /// 过滤出含有效 GPS 的照片。
    public static func photosWithGPS(_ photos: [TimelinePhotoItem]) -> [TimelinePhotoItem] {
        photos.filter(\.hasGPS)
    }

    /// 将含 GPS 的照片按距离聚合为 POI 簇。
    public static func cluster(
        photos: [TimelinePhotoItem],
        radiusMeters: Double = defaultClusterRadiusMeters
    ) -> [TimelineMapCluster] {
        let geoPhotos = photosWithGPS(photos)
        guard !geoPhotos.isEmpty else { return [] }

        var buckets: [MutableBucket] = []
        let sorted = geoPhotos.sorted { $0.id < $1.id }

        for photo in sorted {
            guard let coordinate = photo.coordinate else { continue }
            var assigned = false

            for index in buckets.indices {
                if distanceMeters(
                    from: coordinate,
                    to: buckets[index].center
                ) <= radiusMeters {
                    buckets[index].photos.append(photo)
                    buckets[index].recalculateCenter()
                    assigned = true
                    break
                }
            }

            if !assigned {
                buckets.append(MutableBucket(photos: [photo]))
            }
        }

        return buckets
            .map { bucket in
                TimelineMapCluster(
                    id: bucket.id,
                    latitude: bucket.center.latitude,
                    longitude: bucket.center.longitude,
                    photos: bucket.photos.sorted { $0.takenAt > $1.takenAt }
                )
            }
            .sorted { $0.photos[0].takenAt > $1.photos[0].takenAt }
    }

    // MARK: - Private

    private struct MutableBucket {
        let id: String
        var photos: [TimelinePhotoItem]
        var center: CLLocationCoordinate2D

        init(photos: [TimelinePhotoItem]) {
            self.photos = photos
            id = photos.map(\.id).sorted().joined(separator: "-")
            center = Self.centroid(of: photos)
        }

        mutating func recalculateCenter() {
            center = Self.centroid(of: photos)
        }

        private static func centroid(of photos: [TimelinePhotoItem]) -> CLLocationCoordinate2D {
            let latitudes = photos.compactMap(\.latitude)
            let longitudes = photos.compactMap(\.longitude)
            let count = Double(latitudes.count)
            let latitude = latitudes.reduce(0, +) / count
            let longitude = longitudes.reduce(0, +) / count
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    private static func distanceMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}
