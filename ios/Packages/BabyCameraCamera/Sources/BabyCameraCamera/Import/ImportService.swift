import BabyCameraImageKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 系统相册导入：PHPicker 结果 → EXIF 校验 → 落盘 → `photo` 表写入。
public struct ImportService: Sendable {
    private let pickerLoader: any PickerItemLoading
    private let exifReader: any EXIFReading
    private let metadataWriter: MetadataWriter
    private let fileWriter: any PhotoFileWriting
    private let fileManager: FileManager

    public init(
        pickerLoader: any PickerItemLoading,
        exifReader: any EXIFReading = EXIFReader(),
        metadataWriter: MetadataWriter,
        fileWriter: any PhotoFileWriting,
        fileManager: FileManager = .default
    ) {
        self.pickerLoader = pickerLoader
        self.exifReader = exifReader
        self.metadataWriter = metadataWriter
        self.fileWriter = fileWriter
        self.fileManager = fileManager
    }

    /// 导入单张 PHPicker 选中项。
    public func importPhoto(
        item: PickerImportItem,
        request: ImportRequest
    ) async throws -> ImportResult {
        guard !request.babyIds.isEmpty else {
            throw ImportError.emptyBabyIds
        }

        let data = try await pickerLoader.loadImageData(from: item)
        return try await importPhotoData(data: data, request: request)
    }

    /// 批量导入；单项失败不中断，汇总成功与失败列表。
    public func importPhotos(
        items: [PickerImportItem],
        request: ImportRequest
    ) async throws -> ImportBatchResult {
        guard !request.babyIds.isEmpty else {
            throw ImportError.emptyBabyIds
        }
        guard !items.isEmpty else {
            throw ImportError.emptySelection
        }

        var succeeded: [ImportResult] = []
        var failed: [ImportFailure] = []

        for item in items {
            do {
                let data = try await pickerLoader.loadImageData(from: item)
                let result = try await importPhotoData(data: data, request: request)
                succeeded.append(result)
            } catch let error as ImportError {
                failed.append(ImportFailure(item: item, error: error))
            } catch {
                failed.append(ImportFailure(item: item, error: .loadFailed(error.localizedDescription)))
            }
        }

        return ImportBatchResult(succeeded: succeeded, failed: failed)
    }

    // MARK: - Internal

    func importPhotoData(data: Data, request: ImportRequest) async throws -> ImportResult {
        guard !request.babyIds.isEmpty else {
            throw ImportError.emptyBabyIds
        }

        let tempURL = try writeTemporaryFile(data: data)
        defer { try? fileManager.removeItem(at: tempURL) }

        let exif = try exifReader.read(from: tempURL)
        guard let takenAt = exif.dateTimeOriginal else {
            throw ImportError.missingEXIF
        }

        if isBeforeBirthDate(takenAt: takenAt, babyIds: request.babyIds, babies: request.babies) {
            throw ImportError.beforeBirthDate
        }

        let format = Self.detectFormat(from: data)
        let photoID = UUID()

        let fileURL: URL
        do {
            fileURL = try fileWriter.write(
                data: data,
                format: format,
                photoID: photoID,
                capturedAt: takenAt
            )
        } catch {
            throw ImportError.fileWriteFailed(error.localizedDescription)
        }

        let photoOut = PhotoOut(
            id: photoID,
            fileURL: fileURL,
            format: format,
            capturedAt: takenAt,
            captureLatency: 0,
            didFallbackToJPEG: format == .jpeg
        )

        let metadataResult = try await metadataWriter.write(
            MetadataWriteRequest(
                photoOut: photoOut,
                babyIds: request.babyIds,
                babies: request.babies,
                userId: request.userId
            )
        )

        return ImportResult(
            photoId: metadataResult.photoId,
            takenAt: metadataResult.takenAt,
            fileURL: fileURL
        )
    }

    // MARK: - Private

    private func writeTemporaryFile(data: Data) throws -> URL {
        let url = fileManager.temporaryDirectory
            .appendingPathComponent("import-\(UUID().uuidString).img")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func isBeforeBirthDate(
        takenAt: Date,
        babyIds: [String],
        babies: [BabyMetadataInput]
    ) -> Bool {
        let babyByID = Dictionary(uniqueKeysWithValues: babies.map { ($0.id, $0) })
        let calendar = Calendar.current
        let takenStart = calendar.startOfDay(for: takenAt)

        for babyId in babyIds {
            guard let baby = babyByID[babyId],
                  let birth = Self.birthDateFormatter.date(from: baby.birthDate)
            else {
                continue
            }

            let birthStart = calendar.startOfDay(for: birth)
            if takenStart < birthStart {
                return true
            }
        }

        return false
    }

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func detectFormat(from data: Data) -> ImageFormat {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?
        else {
            return .jpeg
        }

        let normalized = type.lowercased()
        if normalized.contains("heic") || normalized.contains("heif") {
            return .heic
        }
        return .jpeg
    }
}
