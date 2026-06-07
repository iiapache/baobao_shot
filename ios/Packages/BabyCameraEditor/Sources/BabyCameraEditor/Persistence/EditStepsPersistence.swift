import Foundation

/// 编辑步骤 JSON 持久化协议。
public protocol EditStepsPersisting: Sendable {
    func fileURL(for photoId: String) -> URL
    func exists(photoId: String) -> Bool
    func save(steps: [AnyEditStep], photoId: String) throws -> URL
    func load(photoId: String) throws -> [AnyEditStep]
    func delete(photoId: String) throws
}

/// 将 `EditorState.steps` 写入 `meta/edit_steps/{photoId}.json`，支持「重新编辑」恢复。
public struct EditStepsPersistence: EditStepsPersisting {
    public let metaDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        metaDirectory: URL,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.metaDirectory = metaDirectory
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    /// `BabyCameraStore/meta` 根目录。
    public static func defaultStore(metaDirectory: URL) -> EditStepsPersistence {
        EditStepsPersistence(metaDirectory: metaDirectory)
    }

    private var editStepsDirectory: URL {
        metaDirectory.appendingPathComponent("edit_steps", isDirectory: true)
    }

    public func fileURL(for photoId: String) -> URL {
        editStepsDirectory
            .appendingPathComponent("\(photoId).json", isDirectory: false)
    }

    public func exists(photoId: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: photoId).path)
    }

    public func save(steps: [AnyEditStep], photoId: String) throws -> URL {
        try validate(photoId: photoId)
        let directory = editStepsDirectory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = fileURL(for: photoId)
        let data = try encoder.encode(steps)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw EditorPersistenceError.writeFailed
        }
        return url
    }

    public func load(photoId: String) throws -> [AnyEditStep] {
        try validate(photoId: photoId)
        let url = fileURL(for: photoId)
        guard fileManager.fileExists(atPath: url.path) else {
            throw EditorPersistenceError.stepsNotFound(photoId)
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([AnyEditStep].self, from: data)
        } catch let error as EditorPersistenceError {
            throw error
        } catch {
            throw EditorPersistenceError.decodeFailed
        }
    }

    public func delete(photoId: String) throws {
        try validate(photoId: photoId)
        let url = fileURL(for: photoId)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func validate(photoId: String) throws {
        guard !photoId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EditorPersistenceError.photoIdEmpty
        }
    }
}

extension EditStepsPersistence {
    /// 保存完整 `EditorState` 步骤。
    public func save(editorState: EditorState, photoId: String) throws -> URL {
        try save(steps: editorState.steps, photoId: photoId)
    }

    /// 从 JSON 恢复 `EditorState`（不含撤销历史）。
    public func loadEditorState(photoId: String) throws -> EditorState {
        let steps = try load(photoId: photoId)
        return EditorState(steps: steps)
    }
}

extension EditorState {
    /// 持久化当前步骤。
    public func persist(photoId: String, using persistence: EditStepsPersisting) throws -> URL {
        try persistence.save(steps: steps, photoId: photoId)
    }

    /// 从持久化记录恢复。
    public static func restore(photoId: String, using persistence: EditStepsPersisting) throws -> EditorState {
        try persistence.loadEditorState(photoId: photoId)
    }
}
