import BabyCameraImageKit
import Foundation

/// 照片文件写入协议，便于单测注入临时目录。
public protocol PhotoFileWriting: Sendable {
    func write(
        data: Data,
        format: ImageFormat,
        photoID: UUID,
        capturedAt: Date
    ) throws -> URL
}

/// 按 `originals/<yyyy>/<mm>/<photoId>.<ext>` 写入磁盘。
public struct PhotoFileWriter: PhotoFileWriting {
    public let baseDirectory: URL
    private let fileManager: FileManager

    public init(baseDirectory: URL, fileManager: FileManager = .default) {
        self.baseDirectory = baseDirectory
        self.fileManager = fileManager
    }

    public func write(
        data: Data,
        format: ImageFormat,
        photoID: UUID,
        capturedAt: Date
    ) throws -> URL {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: capturedAt)
        let month = calendar.component(.month, from: capturedAt)

        let directory = baseDirectory
            .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", month), isDirectory: true)

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = "\(photoID.uuidString).\(format.fileExtension)"
        let fileURL = directory.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
