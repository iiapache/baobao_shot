import BabyCameraDiagnostics
import Foundation

/// ImageKit 埋点（design-ios §15 + T2.21 缩略图缓存命中率）。
public enum ImageKitAnalytics {
    public enum Event {
        public static let thumbnailCacheHit = AnalyticsEventCatalog.Performance.thumbnailCacheHit
        public static let thumbnailCacheMiss = AnalyticsEventCatalog.Performance.thumbnailCacheMiss
    }

    public static func track(_ event: String, parameters: [String: String] = [:]) {
        AnalyticsService.track(event, parameters: parameters)
    }
}
