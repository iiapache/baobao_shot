import Foundation

/// WidgetKit `kind` 标识（design-ios §11.2：小 / 中 / 大 / 锁屏）。
public enum BabyWidgetKind: String, Sendable, CaseIterable {
    case small = "BabyCameraWidgetSmall"
    case medium = "BabyCameraWidgetMedium"
    case large = "BabyCameraWidgetLarge"
    case lockScreen = "BabyCameraWidgetLockScreen"

    public var identifier: String { rawValue }
}
