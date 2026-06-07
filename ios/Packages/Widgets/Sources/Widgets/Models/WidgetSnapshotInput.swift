import Foundation

public struct WidgetSnapshotBabyInfo: Sendable, Equatable {
    public let id: String
    public let name: String
    public let birthDate: String
    public let avatarSourceURL: URL?

    public init(
        id: String,
        name: String,
        birthDate: String,
        avatarSourceURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.avatarSourceURL = avatarSourceURL
    }
}

public struct WidgetSnapshotPhotoCandidate: Sendable, Equatable {
    public let photoId: String
    public let takenAt: Date
    public let sourceImageURL: URL

    public init(photoId: String, takenAt: Date, sourceImageURL: URL) {
        self.photoId = photoId
        self.takenAt = takenAt
        self.sourceImageURL = sourceImageURL
    }
}

public struct WidgetSnapshotRequest: Sendable {
    public let baby: WidgetSnapshotBabyInfo
    public let photos: [WidgetSnapshotPhotoCandidate]
    public let referenceDate: Date

    public init(
        baby: WidgetSnapshotBabyInfo,
        photos: [WidgetSnapshotPhotoCandidate],
        referenceDate: Date = Date()
    ) {
        self.baby = baby
        self.photos = photos
        self.referenceDate = referenceDate
    }
}
