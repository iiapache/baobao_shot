import Database
import Foundation

/// 可追加照片的内存时间线数据源，供 UI 测试与 Preview 使用。
public actor MutableTimelinePhotoSource: TimelinePhotoSource {
    private var photosByBaby: [String: [PhotoRecord]]

    public init(photos: [PhotoRecord] = [], babyId: String = "baby_e2e") {
        photosByBaby = [babyId: photos.sorted { $0.takenAt > $1.takenAt }]
    }

    public init(photosByBaby: [String: [PhotoRecord]]) {
        self.photosByBaby = photosByBaby.mapValues { $0.sorted { $0.takenAt > $1.takenAt } }
    }

    public func append(_ photo: PhotoRecord) {
        var bucket = photosByBaby[photo.babyIds.first ?? ""] ?? []
        bucket.removeAll { $0.id == photo.id }
        bucket.insert(photo, at: 0)
        let babyId = photo.babyIds.first ?? "baby_e2e"
        photosByBaby[babyId] = bucket.sorted { $0.takenAt > $1.takenAt }
    }

    public func upsert(_ photo: PhotoRecord) {
        append(photo)
    }

    public func photoCount(babyId: String) -> Int {
        photosByBaby[babyId]?.count ?? 0
    }

    public func fetchPhotos(
        babyId: String,
        before takenAt: Int64?,
        limit: Int
    ) async throws -> [PhotoRecord] {
        let all = photosByBaby[babyId] ?? []
        let filtered: [PhotoRecord]
        if let before = takenAt {
            filtered = all.filter { $0.takenAt < before }
        } else {
            filtered = all
        }
        return Array(filtered.prefix(limit))
    }
}
