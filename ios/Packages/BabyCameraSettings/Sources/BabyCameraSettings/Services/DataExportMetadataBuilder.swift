import Database
import Foundation

public struct DataExportMetadataBuilder: Sendable {
    private let appVersion: String
    private let isoFormatter: ISO8601DateFormatter

    public init(appVersion: String, isoFormatter: ISO8601DateFormatter = ISO8601DateFormatter()) {
        self.appVersion = appVersion
        self.isoFormatter = isoFormatter
    }

    public func makeManifest(
        familyId: String,
        babies: [BabyRecord],
        milestones: [MilestoneRecord],
        photos: [DataExportPhoto]
    ) -> DataExportManifest {
        DataExportManifest(
            exportedAt: isoFormatter.string(from: Date()),
            appVersion: appVersion,
            familyId: familyId,
            babies: babies.map(makeBaby),
            milestones: milestones.map(makeMilestone),
            photos: photos
        )
    }

    public func makePhoto(
        from record: PhotoRecord,
        archiveFileName: String
    ) -> DataExportPhoto {
        DataExportPhoto(
            id: record.id,
            babyIds: record.babyIds,
            userId: record.userId,
            takenAt: record.takenAt,
            latitude: record.lat,
            longitude: record.lng,
            sha256: record.sha256,
            exifJSON: record.exifJSON,
            archivePath: archiveFileName,
            localOnly: record.localOnly
        )
    }

    public static func archiveFileName(for photo: PhotoRecord) -> String {
        let ext = URL(fileURLWithPath: photo.filePath).pathExtension
        if ext.isEmpty {
            return photo.id
        }
        return "\(photo.id).\(ext.lowercased())"
    }

    private func makeBaby(_ record: BabyRecord) -> DataExportBaby {
        DataExportBaby(
            id: record.id,
            name: record.name,
            gender: record.gender,
            birthDate: record.birthDate,
            birthTime: record.birthTime
        )
    }

    private func makeMilestone(_ record: MilestoneRecord) -> DataExportMilestone {
        DataExportMilestone(
            id: record.id,
            babyId: record.babyId,
            name: record.name,
            date: record.date,
            kind: record.kind
        )
    }
}
