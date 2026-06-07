import Foundation

public struct WidgetDataSnapshotter: Sendable {
    private let store: any WidgetSnapshotStoring
    private let thumbnailGenerator: any WidgetThumbnailGenerating
    private let timelineReloader: any WidgetTimelineReloading
    private let calendar: Calendar
    private let clock: any WidgetClock

    public init(
        store: any WidgetSnapshotStoring = WidgetAppGroupStore(),
        thumbnailGenerator: any WidgetThumbnailGenerating = WidgetThumbnailGenerator(),
        timelineReloader: any WidgetTimelineReloading = LiveWidgetTimelineReloader(),
        calendar: Calendar = .current,
        clock: any WidgetClock = SystemWidgetClock()
    ) {
        self.store = store
        self.thumbnailGenerator = thumbnailGenerator
        self.timelineReloader = timelineReloader
        self.calendar = calendar
        self.clock = clock
    }

    @discardableResult
    public func snapshot(_ request: WidgetSnapshotRequest) async throws -> WidgetSnapshot {
        let now = clock.now()
        let growthDays = WidgetGrowthDayCalculator.growthDay(
            birthDate: request.baby.birthDate,
            referenceDate: request.referenceDate,
            calendar: calendar
        ) ?? 0

        let representatives = WidgetRepresentativePhotoSelector.select(
            photos: request.photos,
            referenceDate: request.referenceDate,
            calendar: calendar
        )

        var recentDays: [WidgetSnapshotDayEntry] = []
        recentDays.reserveCapacity(representatives.count)

        for photo in representatives {
            let entry = try await writeDayEntry(for: photo)
            recentDays.append(entry)
        }

        let avatarPaths = try await writeAvatarThumbnailsIfNeeded(for: request.baby)

        let snapshot = WidgetSnapshot(
            babyId: request.baby.id,
            babyName: request.baby.name,
            growthDays: growthDays,
            updatedAt: now,
            avatarThumbnailSmall: avatarPaths?.small,
            avatarThumbnailLarge: avatarPaths?.large,
            recentDays: recentDays
        )

        try store.writeSnapshot(snapshot)
        await timelineReloader.reloadAllTimelines()
        return snapshot
    }

    private func writeDayEntry(
        for photo: WidgetSnapshotPhotoCandidate
    ) async throws -> WidgetSnapshotDayEntry {
        let paths = try await writeThumbnails(
            photoId: photo.photoId,
            sourceURL: photo.sourceImageURL
        )
        let date = WidgetGrowthDayCalculator.dayString(for: photo.takenAt, calendar: calendar)

        return WidgetSnapshotDayEntry(
            date: date,
            photoId: photo.photoId,
            thumbnailSmall: paths.small,
            thumbnailLarge: paths.large
        )
    }

    private func writeAvatarThumbnailsIfNeeded(
        for baby: WidgetSnapshotBabyInfo
    ) async throws -> (small: String, large: String)? {
        guard let sourceURL = baby.avatarSourceURL else {
            return nil
        }
        return try await writeThumbnails(photoId: "avatar_\(baby.id)", sourceURL: sourceURL)
    }

    private func writeThumbnails(
        photoId: String,
        sourceURL: URL
    ) async throws -> (small: String, large: String) {
        let imageData: Data
        do {
            imageData = try Data(contentsOf: sourceURL)
        } catch {
            throw WidgetError.sourceImageUnreadable(sourceURL)
        }

        var paths: [WidgetThumbnailSize: String] = [:]
        for size in WidgetThumbnailSize.allCases {
            let jpeg = try thumbnailGenerator.generateJPEG(from: imageData, size: size)
            let relativePath = try store.writeThumbnail(jpeg, photoId: photoId, size: size)
            paths[size] = relativePath
        }

        guard let small = paths[.small], let large = paths[.large] else {
            throw WidgetError.thumbnailGenerationFailed
        }
        return (small, large)
    }
}

public protocol WidgetClock: Sendable {
    func now() -> Date
}

public struct SystemWidgetClock: WidgetClock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}
