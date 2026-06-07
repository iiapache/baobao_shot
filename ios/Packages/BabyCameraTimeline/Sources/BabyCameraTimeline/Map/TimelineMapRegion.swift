import CoreLocation
import Foundation
import MapKit

/// 地图区域风格：中国视图 / 国际视图（V1 均基于 MapKit + region 配置）。
public enum TimelineMapRegionStyle: String, CaseIterable, Identifiable, Sendable {
    case china
    case international

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .china: "中国"
        case .international: "世界"
        }
    }

    /// 按 App 区域给出默认地图风格（CN → 中国，OS → 世界）。
    public static func preferred(forAppRegion regionCode: String) -> TimelineMapRegionStyle {
        regionCode.lowercased() == "os" ? .international : .china
    }
}

/// MapKit 区域配置：默认视野与 POI 自适应。
public enum TimelineMapRegionConfiguration {
    public static func defaultRegion(for style: TimelineMapRegionStyle) -> MKCoordinateRegion {
        switch style {
        case .china:
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.8617, longitude: 104.1954),
                span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 35)
            )
        case .international:
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 160)
            )
        }
    }

    /// 根据 POI 簇计算自适应视野；无簇时回退到风格默认区域。
    public static func regionFitting(
        clusters: [TimelineMapCluster],
        style: TimelineMapRegionStyle,
        paddingFactor: Double = 1.25
    ) -> MKCoordinateRegion {
        guard !clusters.isEmpty else {
            return defaultRegion(for: style)
        }

        let latitudes = clusters.map(\.latitude)
        let longitudes = clusters.map(\.longitude)
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLng = longitudes.min()!
        let maxLng = longitudes.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )

        var latDelta = max((maxLat - minLat) * paddingFactor, 0.02)
        var lngDelta = max((maxLng - minLng) * paddingFactor, 0.02)

        if clusters.count == 1 {
            latDelta = max(latDelta, 0.05)
            lngDelta = max(lngDelta, 0.05)
        }

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        )
    }
}
