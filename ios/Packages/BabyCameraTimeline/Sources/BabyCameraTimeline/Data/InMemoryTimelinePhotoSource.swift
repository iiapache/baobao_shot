import Database
import Foundation

/// 内存照片源，用于 Preview 与单元测试。
public struct InMemoryTimelinePhotoSource: TimelinePhotoSource {
    private let photosByBaby: [String: [PhotoRecord]]

    public init(photos: [PhotoRecord] = [], babyId: String = "baby_1") {
        photosByBaby = [babyId: photos.sorted { $0.takenAt > $1.takenAt }]
    }

    public init(photosByBaby: [String: [PhotoRecord]]) {
        self.photosByBaby = photosByBaby.mapValues { $0.sorted { $0.takenAt > $1.takenAt } }
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
