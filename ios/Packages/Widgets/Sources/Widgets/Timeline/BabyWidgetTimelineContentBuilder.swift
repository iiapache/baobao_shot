import Foundation

public enum BabyWidgetTimelineContentBuilder {
    public static let placeholderBabyName = "宝宝"
    public static let placeholderGrowthDays = 1
    public static let largeWidgetPhotoCount = 4

    public static func placeholder(referenceDate: Date) -> BabyWidgetTimelineContent {
        BabyWidgetTimelineContent(
            date: referenceDate,
            babyId: "placeholder",
            babyName: placeholderBabyName,
            growthDays: placeholderGrowthDays,
            isPlaceholder: true
        )
    }

    public static func build(
        from snapshot: WidgetSnapshot?,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> BabyWidgetTimelinePlan {
        let content: BabyWidgetTimelineContent
        if let snapshot {
            content = content(from: snapshot, referenceDate: referenceDate)
        } else {
            content = empty(referenceDate: referenceDate)
        }

        return BabyWidgetTimelinePlan(
            content: content,
            nextRefreshDate: nextRefreshDate(after: referenceDate, calendar: calendar)
        )
    }

    public static func content(
        from snapshot: WidgetSnapshot,
        referenceDate: Date
    ) -> BabyWidgetTimelineContent {
        let todayPhoto = snapshot.recentDays.first?.thumbnailSmall
        let weekPhotos = snapshot.recentDays
            .prefix(largeWidgetPhotoCount)
            .map(\.thumbnailSmall)

        return BabyWidgetTimelineContent(
            date: referenceDate,
            babyId: snapshot.babyId,
            babyName: snapshot.babyName,
            growthDays: snapshot.growthDays,
            avatarThumbnailPath: snapshot.avatarThumbnailSmall,
            todayPhotoThumbnailPath: todayPhoto,
            weekPhotoThumbnailPaths: Array(weekPhotos),
            isPlaceholder: false
        )
    }

    public static func empty(referenceDate: Date) -> BabyWidgetTimelineContent {
        BabyWidgetTimelineContent(
            date: referenceDate,
            babyId: "",
            babyName: placeholderBabyName,
            growthDays: 0,
            isPlaceholder: false
        )
    }

    public static func nextRefreshDate(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay)
            ?? date.addingTimeInterval(86_400)
    }
}
