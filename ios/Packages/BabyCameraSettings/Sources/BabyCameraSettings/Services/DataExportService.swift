import BabyCameraImageKit
import Database
import Foundation

public protocol DataExportServing: Sendable {
    func export(
        familyId: String,
        progressHandler: @escaping @Sendable (DataExportProgress) -> Void
    ) async throws -> URL
}

/// 端侧数据导出：原图 + metadata.json + timeline.html → zip。
public struct DataExportService: DataExportServing {
    private let babyRepository: any BabyRepository
    private let photoRepository: any PhotoRepository
    private let milestoneRepository: any MilestoneRepository
    private let metadataBuilder: DataExportMetadataBuilder
    private let timelineGenerator: TimelineHTMLGenerator
    private let exifReader: any EXIFReading
    private let fileManager: FileManager
    private let configuration: DataExportConfiguration
    private let exportsDirectory: URL

    public init(
        babyRepository: any BabyRepository,
        photoRepository: any PhotoRepository,
        milestoneRepository: any MilestoneRepository,
        metadataBuilder: DataExportMetadataBuilder,
        timelineGenerator: TimelineHTMLGenerator = TimelineHTMLGenerator(),
        exifReader: any EXIFReading = EXIFReader(),
        fileManager: FileManager = .default,
        configuration: DataExportConfiguration = .default,
        exportsDirectory: URL? = nil
    ) {
        self.babyRepository = babyRepository
        self.photoRepository = photoRepository
        self.milestoneRepository = milestoneRepository
        self.metadataBuilder = metadataBuilder
        self.timelineGenerator = timelineGenerator
        self.exifReader = exifReader
        self.fileManager = fileManager
        self.configuration = configuration
        if let exportsDirectory {
            self.exportsDirectory = exportsDirectory
        } else {
            let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            self.exportsDirectory = caches.appendingPathComponent("DataExports", isDirectory: true)
        }
    }

    public func export(
        familyId: String,
        progressHandler: @escaping @Sendable (DataExportProgress) -> Void
    ) async throws -> URL {
        try fileManager.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)

        let babies = try await babyRepository.fetchAll(familyId: familyId)
        guard !babies.isEmpty else {
            throw DataExportError.familyNotFound
        }

        var totalPhotos = 0
        for baby in babies {
            totalPhotos += try await photoRepository.countByBaby(babyId: baby.id)
        }
        guard totalPhotos > 0 else {
            throw DataExportError.noPhotosToExport
        }

        progressHandler(DataExportProgress(phase: .preparing, completedItems: 0, totalItems: totalPhotos))

        var exportedPhotos: [DataExportPhoto] = []
        exportedPhotos.reserveCapacity(totalPhotos)
        var completed = 0

        let zipURL = exportsDirectory.appendingPathComponent(makeArchiveName())
        let zipWriter = try ZipArchiveWriter(outputURL: zipURL)

        for baby in babies {
            var cursor: Int64?
            while true {
                let page = try await photoRepository.fetchPageByBaby(
                    babyId: baby.id,
                    before: cursor,
                    limit: configuration.pageSize
                )
                guard !page.isEmpty else { break }

                for photo in page {
                    let archiveFileName = DataExportMetadataBuilder.archiveFileName(for: photo)
                    let sourceURL = URL(fileURLWithPath: photo.filePath)
                    guard fileManager.fileExists(atPath: sourceURL.path) else {
                        throw DataExportError.missingPhotoFile(photoId: photo.id)
                    }

                    let zipPath = "\(configuration.photosDirectoryName)/\(archiveFileName)"
                    try zipWriter.appendFile(at: sourceURL, zipPath: zipPath)

                    var exportPhoto = metadataBuilder.makePhoto(from: photo, archiveFileName: archiveFileName)
                    if exportPhoto.exifJSON == nil, let exif = try? exifReader.read(from: sourceURL) {
                        exportPhoto = DataExportPhoto(
                            id: exportPhoto.id,
                            babyIds: exportPhoto.babyIds,
                            userId: exportPhoto.userId,
                            takenAt: exportPhoto.takenAt,
                            latitude: exportPhoto.latitude ?? exif.latitude,
                            longitude: exportPhoto.longitude ?? exif.longitude,
                            sha256: exportPhoto.sha256,
                            exifJSON: exportPhoto.exifJSON,
                            archivePath: exportPhoto.archivePath,
                            localOnly: exportPhoto.localOnly
                        )
                    }

                    exportedPhotos.append(exportPhoto)
                    completed += 1
                    progressHandler(
                        DataExportProgress(
                            phase: .copyingPhotos,
                            completedItems: completed,
                            totalItems: totalPhotos
                        )
                    )
                }

                cursor = page.last?.takenAt
                if page.count < configuration.pageSize {
                    break
                }
            }
        }

        progressHandler(
            DataExportProgress(phase: .writingMetadata, completedItems: completed, totalItems: totalPhotos)
        )

        var milestones: [MilestoneRecord] = []
        for baby in babies {
            milestones.append(contentsOf: try await milestoneRepository.fetchByBaby(babyId: baby.id))
        }

        let manifest = metadataBuilder.makeManifest(
            familyId: familyId,
            babies: babies,
            milestones: milestones,
            photos: exportedPhotos
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let metadataData = try? encoder.encode(manifest) else {
            throw DataExportError.encodingFailed
        }
        try zipWriter.appendData(metadataData, zipPath: configuration.manifestFileName)

        let html = timelineGenerator.generate(
            manifest: manifest,
            photosDirectoryName: configuration.photosDirectoryName
        )
        guard let htmlData = html.data(using: .utf8) else {
            throw DataExportError.encodingFailed
        }
        try zipWriter.appendData(htmlData, zipPath: configuration.timelineFileName)

        progressHandler(
            DataExportProgress(phase: .finalizing, completedItems: completed, totalItems: totalPhotos)
        )
        try zipWriter.close()

        progressHandler(
            DataExportProgress(phase: .completed, completedItems: totalPhotos, totalItems: totalPhotos)
        )
        return zipURL
    }

    private func makeArchiveName() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return "baobao-export-\(stamp).zip"
    }
}
