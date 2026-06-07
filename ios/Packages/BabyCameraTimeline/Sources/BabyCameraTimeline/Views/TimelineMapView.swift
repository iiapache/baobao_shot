import DesignSystem
import MapKit
import SwiftUI

/// 时间线地图视图：MapKit 展示含 GPS 照片 pin，支持 POI 聚合与中外地图切换。
public struct TimelineMapView: View {
    let clusters: [TimelineMapCluster]
    @Binding var regionStyle: TimelineMapRegionStyle

    @State private var region: MKCoordinateRegion

    public init(
        clusters: [TimelineMapCluster],
        regionStyle: Binding<TimelineMapRegionStyle>
    ) {
        self.clusters = clusters
        _regionStyle = regionStyle
        let style = regionStyle.wrappedValue
        _region = State(
            initialValue: TimelineMapRegionConfiguration.regionFitting(
                clusters: clusters,
                style: style
            )
        )
    }

    public var body: some View {
        VStack(spacing: DSSpacing.sm) {
            regionPicker
                .padding(.horizontal, DSSpacing.md)

            Map(coordinateRegion: $region, annotationItems: clusters) { cluster in
                MapAnnotation(coordinate: cluster.coordinate) {
                    TimelineMapPinView(cluster: cluster)
                }
            }
            .accessibilityIdentifier("timelineMapView")
        }
        .onChange(of: regionStyle) { newStyle in
            region = TimelineMapRegionConfiguration.regionFitting(
                clusters: clusters,
                style: newStyle
            )
        }
        .onChange(of: clusters.map(\.id)) { _ in
            region = TimelineMapRegionConfiguration.regionFitting(
                clusters: clusters,
                style: regionStyle
            )
        }
    }

    private var regionPicker: some View {
        Picker("地图区域", selection: $regionStyle) {
            ForEach(TimelineMapRegionStyle.allCases) { style in
                Text(style.title).tag(style)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("timelineMapRegionPicker")
    }
}

struct TimelineMapPinView: View {
    let cluster: TimelineMapCluster

    var body: some View {
        if cluster.isCluster {
            ZStack {
                Circle()
                    .fill(DSColors.primary)
                    .frame(width: 36, height: 36)
                Text("\(cluster.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("\(cluster.count) 张照片")
        } else {
            Image(systemName: "mappin.circle.fill")
                .font(.title)
                .foregroundStyle(DSColors.primary)
                .accessibilityLabel("照片位置")
        }
    }
}
