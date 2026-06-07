import Foundation

enum MainTabEditorPaths {
    static var metaDirectory: URL {
        CameraStorePaths.storeRoot.appendingPathComponent("meta", isDirectory: true)
    }

    static var editedDirectory: URL {
        CameraStorePaths.storeRoot.appendingPathComponent("edited", isDirectory: true)
    }

    static func editedFileURL(photoId: String) -> URL {
        editedDirectory.appendingPathComponent("\(photoId).jpg", isDirectory: false)
    }
}

/// 记录未编辑原图路径，供重新编辑时作为渲染基底。
struct EditorOriginalPathStore: Sendable {
    let metaDirectory: URL
    private let fileManager: FileManager

    init(metaDirectory: URL, fileManager: FileManager = .default) {
        self.metaDirectory = metaDirectory
        self.fileManager = fileManager
    }

    private var directory: URL {
        metaDirectory.appendingPathComponent("original_paths", isDirectory: true)
    }

    func save(originalPath: String, for photoId: String) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(photoId).path", isDirectory: false)
        try originalPath.write(to: url, atomically: true, encoding: .utf8)
    }

    func load(photoId: String) -> String? {
        let url = directory.appendingPathComponent("\(photoId).path", isDirectory: false)
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
