import Foundation

/// 分组后的时间线区块。
public struct TimelineSection: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let sortKey: Int64
    public let photos: [TimelinePhotoItem]

    public init(id: String, title: String, sortKey: Int64, photos: [TimelinePhotoItem]) {
        self.id = id
        self.title = title
        self.sortKey = sortKey
        self.photos = photos
    }
}
