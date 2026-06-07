import SwiftUI

/// App 生命周期埋点（design-ios §15.1 启动 / 生命周期）。
public struct AnalyticsLifecycleTracker: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    private static let firstOpenKey = "com.babycamera.analytics.firstOpen"

    public init() {}

    public func body(content: Content) -> some View {
        content
            .onAppear {
                AnalyticsFeatureTracks.trackAppLaunch(coldStart: true)
                if !UserDefaults.standard.bool(forKey: Self.firstOpenKey) {
                    UserDefaults.standard.set(true, forKey: Self.firstOpenKey)
                    AnalyticsFeatureTracks.trackAppFirstOpen()
                }
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    AnalyticsFeatureTracks.trackAppActive()
                case .background:
                    AnalyticsFeatureTracks.trackAppBackground()
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
    }
}

public extension View {
    func trackAnalyticsLifecycle() -> some View {
        modifier(AnalyticsLifecycleTracker())
    }
}
