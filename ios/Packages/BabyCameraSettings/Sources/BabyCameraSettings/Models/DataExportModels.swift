import Foundation

public enum DataExportPhase: String, Sendable, Equatable, Codable {
    case preparing
    case copyingPhotos
    case writingMetadata
    case finalizing
    case completed
    case failed
}

public struct DataExportProgress: Sendable, Equatable {
    public let phase: DataExportPhase
    public let completedItems: Int
    public let totalItems: Int

    public init(phase: DataExportPhase, completedItems: Int, totalItems: Int) {
        self.phase = phase
        self.completedItems = completedItems
        self.totalItems = totalItems
    }

    public var fractionCompleted: Double {
        guard totalItems > 0 else { return 0 }
        return min(1, Double(completedItems) / Double(totalItems))
    }
}

public struct DataExportManifest: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public let version: Int
    public let exportedAt: String
    public let appVersion: String
    public let familyId: String
    public let babies: [DataExportBaby]
    public let milestones: [DataExportMilestone]
    public let photos: [DataExportPhoto]

    public init(
        version: Int = Self.currentVersion,
        exportedAt: String,
        appVersion: String,
        familyId: String,
        babies: [DataExportBaby],
        milestones: [DataExportMilestone],
        photos: [DataExportPhoto]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.familyId = familyId
        self.babies = babies
        self.milestones = milestones
        self.photos = photos
    }
}

public struct DataExportBaby: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let gender: String?
    public let birthDate: String
    public let birthTime: String?

    public init(
        id: String,
        name: String,
        gender: String? = nil,
        birthDate: String,
        birthTime: String? = nil
    ) {
        self.id = id
        self.name = name
        self.gender = gender
        self.birthDate = birthDate
        self.birthTime = birthTime
    }
}

public struct DataExportMilestone: Codable, Sendable, Equatable {
    public let id: String
    public let babyId: String
    public let name: String
    public let date: Int64
    public let kind: String

    public init(id: String, babyId: String, name: String, date: Int64, kind: String) {
        self.id = id
        self.babyId = babyId
        self.name = name
        self.date = date
        self.kind = kind
    }
}

public struct DataExportPhoto: Codable, Sendable, Equatable {
    public let id: String
    public let babyIds: [String]
    public let userId: String
    public let takenAt: Int64
    public let latitude: Double?
    public let longitude: Double?
    public let sha256: String
    public let exifJSON: String?
    public let archivePath: String
    public let localOnly: Bool

    public init(
        id: String,
        babyIds: [String],
        userId: String,
        takenAt: Int64,
        latitude: Double? = nil,
        longitude: Double? = nil,
        sha256: String,
        exifJSON: String? = nil,
        archivePath: String,
        localOnly: Bool
    ) {
        self.id = id
        self.babyIds = babyIds
        self.userId = userId
        self.takenAt = takenAt
        self.latitude = latitude
        self.longitude = longitude
        self.sha256 = sha256
        self.exifJSON = exifJSON
        self.archivePath = archivePath
        self.localOnly = localOnly
    }
}

public enum DataExportError: Error, Equatable, Sendable {
    case familyNotFound
    case noPhotosToExport
    case missingPhotoFile(photoId: String)
    case zipCreationFailed
    case encodingFailed
    case cancelled
}

public struct DataExportConfiguration: Sendable {
    public static let pageSize = 200
    public static let backgroundTaskIdentifier = "com.babycamera.background.data-export"
    public static let manifestFileName = "metadata.json"
    public static let timelineFileName = "timeline.html"
    public static let photosDirectoryName = "photos"

    public let pageSize: Int
    public let manifestFileName: String
    public let timelineFileName: String
    public let photosDirectoryName: String

    public init(
        pageSize: Int = Self.pageSize,
        manifestFileName: String = Self.manifestFileName,
        timelineFileName: String = Self.timelineFileName,
        photosDirectoryName: String = Self.photosDirectoryName
    ) {
        self.pageSize = pageSize
        self.manifestFileName = manifestFileName
        self.timelineFileName = timelineFileName
        self.photosDirectoryName = photosDirectoryName
    }

    public static let `default` = DataExportConfiguration()
}
