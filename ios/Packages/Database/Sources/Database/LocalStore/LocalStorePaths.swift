import Foundation

public enum DerivedAssetKind: String, Sendable, Equatable {
    case local
    case aiImage
    case aiVideo
}

/// `Library/BabyCameraStore/` path helpers (design-ios §5.1).
public struct LocalStorePaths: Sendable {
    public let storeRoot: URL
    private let calendar: Calendar
    private let fileManager: FileManager

    public init(
        storeRoot: URL,
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) {
        self.storeRoot = storeRoot
        self.calendar = calendar
        self.fileManager = fileManager
    }

    public func derivedDirectory(babyId: String, date: Date) -> URL {
        let components = dateComponents(for: date)
        return storeRoot
            .appendingPathComponent("derived", isDirectory: true)
            .appendingPathComponent(babyId, isDirectory: true)
            .appendingPathComponent(components.year, isDirectory: true)
            .appendingPathComponent(components.month, isDirectory: true)
    }

    public func videosDirectory(babyId: String, date: Date) -> URL {
        let components = dateComponents(for: date)
        return storeRoot
            .appendingPathComponent("videos", isDirectory: true)
            .appendingPathComponent(babyId, isDirectory: true)
            .appendingPathComponent(components.year, isDirectory: true)
            .appendingPathComponent(components.month, isDirectory: true)
    }

    public func derivedFileURL(
        babyId: String,
        derivedId: String,
        kind: DerivedAssetKind,
        date: Date = Date()
    ) -> URL {
        switch kind {
        case .aiVideo:
            return videosDirectory(babyId: babyId, date: date)
                .appendingPathComponent("\(derivedId).mp4", isDirectory: false)
        case .local, .aiImage:
            return derivedDirectory(babyId: babyId, date: date)
                .appendingPathComponent("\(derivedId).heic", isDirectory: false)
        }
    }

    /// `thumbnails/<derivedId>_<maxEdge>.heic`（design-ios §5.1）。
    public func thumbnailFileURL(derivedId: String, maxEdgeLength: Int) -> URL {
        storeRoot
            .appendingPathComponent("thumbnails", isDirectory: true)
            .appendingPathComponent("\(derivedId)_\(maxEdgeLength).heic", isDirectory: false)
    }

    @discardableResult
    public func ensureDirectory(for fileURL: URL) throws -> URL {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return fileURL
    }

    private func dateComponents(for date: Date) -> (year: String, month: String) {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return (String(format: "%04d", year), String(format: "%02d", month))
    }
}
