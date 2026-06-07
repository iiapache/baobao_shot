import Foundation

/// `widget_snapshot.json` 落盘结构，供主 App 与 Widget Extension 共享读取。
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public let version: Int
    public let babyId: String
    public let babyName: String
    public let growthDays: Int
    public let updatedAt: Date
    public let avatarThumbnailSmall: String?
    public let avatarThumbnailLarge: String?
    public let recentDays: [WidgetSnapshotDayEntry]

    public init(
        version: Int = WidgetAppGroupConfiguration.snapshotVersion,
        babyId: String,
        babyName: String,
        growthDays: Int,
        updatedAt: Date,
        avatarThumbnailSmall: String? = nil,
        avatarThumbnailLarge: String? = nil,
        recentDays: [WidgetSnapshotDayEntry]
    ) {
        self.version = version
        self.babyId = babyId
        self.babyName = babyName
        self.growthDays = growthDays
        self.updatedAt = updatedAt
        self.avatarThumbnailSmall = avatarThumbnailSmall
        self.avatarThumbnailLarge = avatarThumbnailLarge
        self.recentDays = recentDays
    }
}

public struct WidgetSnapshotDayEntry: Codable, Sendable, Equatable {
    public let date: String
    public let photoId: String
    public let thumbnailSmall: String
    public let thumbnailLarge: String

    public init(
        date: String,
        photoId: String,
        thumbnailSmall: String,
        thumbnailLarge: String
    ) {
        self.date = date
        self.photoId = photoId
        self.thumbnailSmall = thumbnailSmall
        self.thumbnailLarge = thumbnailLarge
    }
}
