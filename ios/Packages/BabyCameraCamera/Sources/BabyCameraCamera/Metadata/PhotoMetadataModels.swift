import Foundation

/// 写入元数据所需的宝宝信息（成长天数计算）。
public struct BabyMetadataInput: Sendable, Equatable {
    public let id: String
    public let birthDate: String

    public init(id: String, birthDate: String) {
        self.id = id
        self.birthDate = birthDate
    }
}

/// 拍摄位置（优先于文件内 GPS）。
public struct PhotoLocation: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// MetadataWriter 输入。
public struct MetadataWriteRequest: Sendable {
    public let photoOut: PhotoOut
    public let babyIds: [String]
    public let babies: [BabyMetadataInput]
    public let userId: String
    public let location: PhotoLocation?
    /// 相机拍摄时文件内无 EXIF，可用 `PhotoOut.capturedAt` 作为 `DateTimeOriginal`。
    public let captureTakenAtFallback: Date?

    public init(
        photoOut: PhotoOut,
        babyIds: [String],
        babies: [BabyMetadataInput],
        userId: String,
        location: PhotoLocation? = nil,
        captureTakenAtFallback: Date? = nil
    ) {
        self.photoOut = photoOut
        self.babyIds = babyIds
        self.babies = babies
        self.userId = userId
        self.location = location
        self.captureTakenAtFallback = captureTakenAtFallback
    }
}

/// 合并后的 EXIF + 业务元数据，序列化进 `photo.exif` 列。
public struct MergedEXIFPayload: Codable, Equatable, Sendable {
    public let dateTimeOriginal: String
    public let latitude: Double?
    public let longitude: Double?
    public let babyIds: [String]
    public let growthDays: [String: Int]

    public init(
        dateTimeOriginal: String,
        latitude: Double?,
        longitude: Double?,
        babyIds: [String],
        growthDays: [String: Int]
    ) {
        self.dateTimeOriginal = dateTimeOriginal
        self.latitude = latitude
        self.longitude = longitude
        self.babyIds = babyIds
        self.growthDays = growthDays
    }

    public func jsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw MetadataError.persistenceFailed("exif json encode failed")
        }
        return string
    }
}

/// MetadataWriter 输出。
public struct MetadataWriteResult: Sendable, Equatable {
    public let photoId: String
    public let takenAt: Date
    public let mergedEXIF: MergedEXIFPayload

    public init(photoId: String, takenAt: Date, mergedEXIF: MergedEXIFPayload) {
        self.photoId = photoId
        self.takenAt = takenAt
        self.mergedEXIF = mergedEXIF
    }
}
