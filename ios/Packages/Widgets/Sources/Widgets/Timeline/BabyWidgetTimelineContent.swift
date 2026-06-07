import Foundation

/// Widget Timeline 展示数据，与 WidgetKit 解耦便于单测。
public struct BabyWidgetTimelineContent: Equatable, Sendable {
    public let date: Date
    public let babyId: String
    public let babyName: String
    public let growthDays: Int
    public let avatarThumbnailPath: String?
    public let todayPhotoThumbnailPath: String?
    public let weekPhotoThumbnailPaths: [String]
    public let isPlaceholder: Bool

    public init(
        date: Date,
        babyId: String,
        babyName: String,
        growthDays: Int,
        avatarThumbnailPath: String? = nil,
        todayPhotoThumbnailPath: String? = nil,
        weekPhotoThumbnailPaths: [String] = [],
        isPlaceholder: Bool = false
    ) {
        self.date = date
        self.babyId = babyId
        self.babyName = babyName
        self.growthDays = growthDays
        self.avatarThumbnailPath = avatarThumbnailPath
        self.todayPhotoThumbnailPath = todayPhotoThumbnailPath
        self.weekPhotoThumbnailPaths = weekPhotoThumbnailPaths
        self.isPlaceholder = isPlaceholder
    }
}

public struct BabyWidgetTimelinePlan: Equatable, Sendable {
    public let content: BabyWidgetTimelineContent
    public let nextRefreshDate: Date

    public init(content: BabyWidgetTimelineContent, nextRefreshDate: Date) {
        self.content = content
        self.nextRefreshDate = nextRefreshDate
    }
}
