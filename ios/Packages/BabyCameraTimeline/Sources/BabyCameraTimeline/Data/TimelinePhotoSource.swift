import Database
import Foundation

/// 时间线照片数据源（支持分页游标）。
public protocol TimelinePhotoSource: Sendable {
    func fetchPhotos(
        babyId: String,
        before takenAt: Int64?,
        limit: Int
    ) async throws -> [PhotoRecord]
}

/// 基于 `PhotoRepository` 的分页数据源。
public struct PhotoRepositoryTimelineSource: TimelinePhotoSource {
    private let repository: any PhotoRepository
    private let maxFetch: Int

    public init(repository: any PhotoRepository, maxFetch: Int = 10_000) {
        self.repository = repository
        self.maxFetch = maxFetch
    }

    public func fetchPhotos(
        babyId: String,
        before takenAt: Int64?,
        limit: Int
    ) async throws -> [PhotoRecord] {
        let batch = try await repository.fetchByBaby(babyId: babyId, limit: maxFetch)
        let sorted = batch.sorted { $0.takenAt > $1.takenAt }
        let filtered: [PhotoRecord]
        if let before = takenAt {
            filtered = sorted.filter { $0.takenAt < before }
        } else {
            filtered = sorted
        }
        return Array(filtered.prefix(limit))
    }
}
