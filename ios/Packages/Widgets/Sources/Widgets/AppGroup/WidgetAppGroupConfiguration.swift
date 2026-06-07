import Foundation

/// App Group 与 Widget 快照文件布局（design-ios §11.1）。
public enum WidgetAppGroupConfiguration: Sendable {
    public static let groupIdentifier = "group.app.babycamera"
    public static let snapshotFileName = "widget_snapshot.json"
    public static let thumbnailsDirectoryName = "thumbnails"
    public static let snapshotVersion = 1
}
