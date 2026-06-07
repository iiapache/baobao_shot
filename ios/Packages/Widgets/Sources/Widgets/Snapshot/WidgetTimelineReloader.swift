import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

public protocol WidgetTimelineReloading: Sendable {
    func reloadAllTimelines() async
}

public struct LiveWidgetTimelineReloader: WidgetTimelineReloading {
    public init() {}

    public func reloadAllTimelines() async {
#if canImport(WidgetKit)
        for kind in BabyWidgetKind.allCases {
            WidgetCenter.shared.reloadTimelines(ofKind: kind.identifier)
        }
#endif
    }
}

public struct NoOpWidgetTimelineReloader: WidgetTimelineReloading {
    public init() {}

    public func reloadAllTimelines() async {}
}
