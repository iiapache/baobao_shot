import BabyCameraImageKit
import CryptoKit
import Database
import Foundation

/// 合并 EXIF + 宝宝 ID + 成长天数 + 位置，并写入 `photo` 表（离线优先）。
public struct MetadataWriter: Sendable {
    private let exifReader: any EXIFReading
    private let photoRepository: any PhotoRepository
    private let fileManager: FileManager

    public init(
        exifReader: any EXIFReading = EXIFReader(),
        photoRepository: any PhotoRepository,
        fileManager: FileManager = .default
    ) {
        self.exifReader = exifReader
        self.photoRepository = photoRepository
        self.fileManager = fileManager
    }

    /// 解析元数据并插入 `photo` 表。`captureTakenAtFallback` 为 `nil` 且文件无 EXIF 时拒绝写入。
    public func write(_ request: MetadataWriteRequest) async throws -> MetadataWriteResult {
        guard !request.babyIds.isEmpty else {
            throw MetadataError.emptyBabyIds
        }

        guard fileManager.fileExists(atPath: request.photoOut.fileURL.path) else {
            throw MetadataError.fileNotReadable
        }

        let fileEXIF = try exifReader.read(from: request.photoOut.fileURL)
        let takenAt = try resolveTakenAt(fileEXIF: fileEXIF, request: request)

        let latitude = request.location?.latitude ?? fileEXIF.latitude
        let longitude = request.location?.longitude ?? fileEXIF.longitude

        let growthDays = computeGrowthDays(
            babyIds: request.babyIds,
            babies: request.babies,
            takenAt: takenAt
        )

        let merged = MergedEXIFPayload(
            dateTimeOriginal: EXIFReader.exifDateTimeString(from: takenAt),
            latitude: latitude,
            longitude: longitude,
            babyIds: request.babyIds,
            growthDays: growthDays
        )

        let fileData = try Data(contentsOf: request.photoOut.fileURL)
        let sha256 = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
        let now = Int64(Date().timeIntervalSince1970)

        let record = PhotoRecord(
            id: request.photoOut.id.uuidString,
            babyIds: request.babyIds,
            userId: request.userId,
            takenAt: Int64(takenAt.timeIntervalSince1970),
            lat: latitude,
            lng: longitude,
            sha256: sha256,
            exifJSON: try merged.jsonString(),
            filePath: request.photoOut.fileURL.path,
            localOnly: true,
            updatedAt: now
        )

        try await photoRepository.save(record)

        return MetadataWriteResult(
            photoId: record.id,
            takenAt: takenAt,
            mergedEXIF: merged
        )
    }

    // MARK: - Private

    private func resolveTakenAt(
        fileEXIF: EXIFMetadata,
        request: MetadataWriteRequest
    ) throws -> Date {
        if let takenAt = fileEXIF.dateTimeOriginal {
            return takenAt
        }
        if let fallback = request.captureTakenAtFallback {
            return fallback
        }
        throw MetadataError.missingDateTimeOriginal
    }

    private func computeGrowthDays(
        babyIds: [String],
        babies: [BabyMetadataInput],
        takenAt: Date
    ) -> [String: Int] {
        let babyByID = Dictionary(uniqueKeysWithValues: babies.map { ($0.id, $0) })
        var result: [String: Int] = [:]

        for babyId in babyIds {
            guard let baby = babyByID[babyId],
                  let day = GrowthDayCalculator.growthDay(birthDate: baby.birthDate, takenAt: takenAt)
            else {
                continue
            }
            result[babyId] = day
        }

        return result
    }
}
