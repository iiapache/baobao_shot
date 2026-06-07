import Database
import Foundation

/// 按日 / 月 / 年 / 全部 维度聚合照片记录。
public enum TimelineGrouping {
    /// 将照片按视图维度分组，组内与组间均按 `takenAt` 降序排列。
    public static func group(
        photos: [PhotoRecord],
        scale: TimelineScale,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [TimelineSection] {
        let items = photos
            .map(TimelinePhotoItem.init(photo:))
            .sorted { $0.takenAt > $1.takenAt }

        guard !items.isEmpty else { return [] }

        switch scale {
        case .map:
            return []
        case .all:
            return [
                TimelineSection(
                    id: "all",
                    title: "全部",
                    sortKey: items[0].takenAt,
                    photos: items
                ),
            ]
        case .day, .month, .year:
            let buckets = bucketItems(items, scale: scale, calendar: calendar, locale: locale)
            return buckets
                .sorted { $0.sortKey > $1.sortKey }
        }
    }

    /// 分组并展平为虚拟列表行。
    public static func makeRows(
        photos: [PhotoRecord],
        scale: TimelineScale,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [TimelineRow] {
        let sections = group(
            photos: photos,
            scale: scale,
            calendar: calendar,
            locale: locale
        )
        let includeHeaders = scale != .all
        return TimelineRow.flatten(sections: sections, includeHeaders: includeHeaders)
    }

    // MARK: - Private

    private struct Bucket {
        let id: String
        let title: String
        let sortKey: Int64
        var photos: [TimelinePhotoItem]
    }

    private static func bucketItems(
        _ items: [TimelinePhotoItem],
        scale: TimelineScale,
        calendar: Calendar,
        locale: Locale
    ) -> [TimelineSection] {
        var buckets: [String: Bucket] = [:]
        var bucketOrder: [String] = []

        for item in items {
            let date = Date(timeIntervalSince1970: TimeInterval(item.takenAt))
            let key = bucketKey(for: date, scale: scale, calendar: calendar, locale: locale)
            if buckets[key.id] == nil {
                buckets[key.id] = Bucket(
                    id: key.id,
                    title: key.title,
                    sortKey: key.sortKey,
                    photos: []
                )
                bucketOrder.append(key.id)
            }
            buckets[key.id]?.photos.append(item)
        }

        return bucketOrder.compactMap { id in
            guard let bucket = buckets[id] else { return nil }
            let sortedPhotos = bucket.photos.sorted { $0.takenAt > $1.takenAt }
            return TimelineSection(
                id: bucket.id,
                title: bucket.title,
                sortKey: bucket.sortKey,
                photos: sortedPhotos
            )
        }
    }

    private struct BucketKey {
        let id: String
        let title: String
        let sortKey: Int64
    }

    private static func bucketKey(
        for date: Date,
        scale: TimelineScale,
        calendar: Calendar,
        locale: Locale
    ) -> BucketKey {
        switch scale {
        case .day:
            let start = calendar.startOfDay(for: date)
            let components = calendar.dateComponents([.year, .month, .day], from: start)
            let id = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
            let title = dayTitle(for: start, calendar: calendar, locale: locale)
            return BucketKey(id: id, title: title, sortKey: Int64(start.timeIntervalSince1970))
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            let year = components.year ?? 0
            let month = components.month ?? 0
            let id = String(format: "%04d-%02d", year, month)
            let title = monthTitle(year: year, month: month)
            var monthStart = DateComponents(year: year, month: month, day: 1)
            let start = calendar.date(from: monthStart) ?? date
            return BucketKey(id: id, title: title, sortKey: Int64(start.timeIntervalSince1970))
        case .year:
            let year = calendar.component(.year, from: date)
            let id = String(format: "%04d", year)
            let title = "\(year) 年"
            var yearStart = DateComponents(year: year, month: 1, day: 1)
            let start = calendar.date(from: yearStart) ?? date
            return BucketKey(id: id, title: title, sortKey: Int64(start.timeIntervalSince1970))
        case .all:
            return BucketKey(id: "all", title: "全部", sortKey: Int64(date.timeIntervalSince1970))
        case .map:
            return BucketKey(id: "map", title: "地图", sortKey: Int64(date.timeIntervalSince1970))
        }
    }

    private static func dayTitle(for date: Date, calendar: Calendar, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: date)
    }

    private static func monthTitle(year: Int, month: Int) -> String {
        "\(year) 年 \(month) 月"
    }
}
