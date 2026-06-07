import BabyCameraDiagnostics
import BabyCameraEditor
import BabyCameraImageKit
import CoreImage
import CryptoKit
import Database
import Foundation

/// 主 App 编辑流：拍照/选图 → 编辑导出 → 更新 `photo` 表 → Timeline 可见。
@MainActor
final class MainTabEditorFlowStore: ObservableObject, PhotoEditorFlowManaging {
    struct ActiveSession: Identifiable, Equatable {
        let photoId: String
        let isReEdit: Bool

        var id: String { "\(photoId)-\(isReEdit)" }
    }

    @Published private(set) var activeSession: ActiveSession?
    @Published private(set) var isSaving = false
    @Published private(set) var statusMessage = ""
    @Published var toolbarBinding = EditorToolbarBinding()

    let reEditCompleteButtonTitle = "保存并完成"

    var onEditorDidSave: (() -> Void)?

    private let photoRepository: any PhotoRepository
    private let editStepsPersistence: EditStepsPersistence
    private let originalPathStore: EditorOriginalPathStore
    private var baseImages: [String: CIImage] = [:]
    private var editorStates: [String: EditorState] = [:]

    init(appDatabase: AppDatabase) {
        photoRepository = appDatabase.makePhotoRepository()
        let metaDirectory = MainTabEditorPaths.metaDirectory
        editStepsPersistence = EditStepsPersistence(metaDirectory: metaDirectory)
        originalPathStore = EditorOriginalPathStore(metaDirectory: metaDirectory)
        try? FileManager.default.createDirectory(
            at: MainTabEditorPaths.editedDirectory,
            withIntermediateDirectories: true
        )
    }

    func presentEditor(photoId: String, isReEdit: Bool) {
        let start = CFAbsoluteTimeGetCurrent()
        let source = isReEdit ? "reedit" : "camera"
        Task {
            do {
                try await prepareEditor(photoId: photoId, isReEdit: isReEdit)
                toolbarBinding = EditorToolbarBinding()
                activeSession = ActiveSession(photoId: photoId, isReEdit: isReEdit)
                statusMessage = isReEdit ? "重新编辑" : "编辑照片"
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                _ = PerformanceTracker.recordEditorOpen(elapsedSeconds: elapsed, source: source)
            } catch {
                statusMessage = "无法打开编辑器: \(error.localizedDescription)"
            }
        }
    }

    func dismissEditor() {
        activeSession = nil
    }

    func applyCurrentFilter(to photoId: String) {
        var binding = toolbarBinding
        binding.activePanel = .filter
        binding.commitActivePanel(to: editorState(for: photoId))
        toolbarBinding = binding
        statusMessage = "已应用滤镜 \(binding.filter.filterID.rawValue)"
    }

    func savePhoto(photoId: String) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let editorState = editorState(for: photoId)
            let baseImage = try baseImage(for: photoId)
            let exportService = try EditorExportService()
            let outputURL = MainTabEditorPaths.editedFileURL(photoId: photoId)
            let result = try exportService.exportToFile(
                baseImage: baseImage,
                editorState: editorState,
                options: EditorExportOptions(format: .jpeg),
                outputURL: outputURL
            )

            guard var record = try await photoRepository.fetch(id: photoId) else {
                throw MainTabEditorError.photoNotFound
            }

            if originalPathStore.load(photoId: photoId) == nil {
                try originalPathStore.save(originalPath: record.filePath, for: photoId)
            }

            let digest = SHA256.hash(data: result.encoded.data)
            let sha256 = digest.map { String(format: "%02x", $0) }.joined()
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            record.filePath = outputURL.path
            record.sha256 = sha256
            record.updatedAt = now

            try await photoRepository.save(record)
            try editStepsPersistence.save(editorState: editorState, photoId: photoId)

            statusMessage = "保存成功"
            activeSession = nil
            onEditorDidSave?()
        } catch {
            statusMessage = "保存失败: \(error.localizedDescription)"
        }
    }

    func finishReEditAndReturnToCamera(photoId: String) async {
        await savePhoto(photoId: photoId)
    }

    private func prepareEditor(photoId: String, isReEdit: Bool) async throws {
        if isReEdit, editStepsPersistence.exists(photoId: photoId) {
            editorStates[photoId] = try EditorState.restore(photoId: photoId, using: editStepsPersistence)
        } else {
            editorStates[photoId] = EditorState()
        }

        if baseImages[photoId] == nil {
            let originalPath = try await resolveOriginalPath(photoId: photoId)
            guard let image = CIImage(contentsOf: URL(fileURLWithPath: originalPath)) else {
                throw MainTabEditorError.unreadableImage(originalPath)
            }
            baseImages[photoId] = image
        }
    }

    private func resolveOriginalPath(photoId: String) async throws -> String {
        if let stored = originalPathStore.load(photoId: photoId) {
            return stored
        }
        guard let record = try await photoRepository.fetch(id: photoId) else {
            throw MainTabEditorError.photoNotFound
        }
        return record.filePath
    }

    private func editorState(for photoId: String) -> EditorState {
        if let state = editorStates[photoId] {
            return state
        }
        let state = EditorState()
        editorStates[photoId] = state
        return state
    }

    private func baseImage(for photoId: String) throws -> CIImage {
        if let image = baseImages[photoId] {
            return image
        }
        throw MainTabEditorError.missingBaseImage
    }
}

enum MainTabEditorError: Error {
    case photoNotFound
    case missingBaseImage
    case unreadableImage(String)
}
