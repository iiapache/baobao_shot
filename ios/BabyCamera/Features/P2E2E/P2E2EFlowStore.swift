import BabyCameraBaby
import BabyCameraEditor
import BabyCameraImageKit
import BabyCameraTimeline
import CoreImage
import CryptoKit
import Database
import Foundation

/// P2 端到端流程状态：mock 拍照 → 编辑 → 保存 → Timeline → 重新编辑。
@MainActor
final class P2E2EFlowStore: ObservableObject {
    enum Screen: Equatable {
        case mockCamera
        case editor(photoId: String, isReEdit: Bool)
        case timeline
    }

    @Published private(set) var screen: Screen = .mockCamera
    @Published private(set) var completedCycles = 0
    @Published private(set) var savedPhotoCount = 0
    @Published private(set) var isSaving = false
    @Published private(set) var statusMessage = "准备拍照"
    @Published var toolbarBinding = EditorToolbarBinding()

    let babyStore: CurrentBabyEnvironment
    let photoSource: MutableTimelinePhotoSource
    let offlineMode: Bool

    private let editStepsPersistence: EditStepsPersistence
    private let photosDirectory: URL
    private let metaDirectory: URL
    private var savedPhotoIds = Set<String>()
    private var baseImages: [String: CIImage] = [:]
    private var editorStates: [String: EditorState] = [:]

    init(offlineMode: Bool = false) {
        self.offlineMode = offlineMode
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("P2E2E-\(UUID().uuidString)", isDirectory: true)
        photosDirectory = root.appendingPathComponent("photos", isDirectory: true)
        metaDirectory = root.appendingPathComponent("meta", isDirectory: true)
        editStepsPersistence = EditStepsPersistence(metaDirectory: metaDirectory)
        photoSource = MutableTimelinePhotoSource()
        babyStore = CurrentBabyEnvironment(restorePersistedSelection: false)

        try? fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: metaDirectory, withIntermediateDirectories: true)

        let baby = BabyProfile(
            id: "baby_e2e",
            familyId: "family_e2e",
            name: "测试宝宝",
            birthDate: "2024-01-01"
        )
        babyStore.upsert(baby)
        babyStore.select(babyId: baby.id)
    }

    func mockCapturePhoto() {
        let photoId = "photo_\(UUID().uuidString.prefix(8))"
        let image = Self.makeMockCIImage(seed: photoId)
        baseImages[photoId] = image
        editorStates[photoId] = EditorState()
        toolbarBinding = EditorToolbarBinding()
        screen = .editor(photoId: photoId, isReEdit: false)
        statusMessage = "已 mock 拍照，进入编辑"
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
            let fileURL = photosDirectory.appendingPathComponent("\(photoId).jpg")
            let result = try exportService.exportToFile(
                baseImage: baseImage,
                editorState: editorState,
                options: EditorExportOptions(format: .jpeg),
                outputURL: fileURL
            )

            let digest = SHA256.hash(data: result.encoded.data)
            let sha256 = digest.map { String(format: "%02x", $0) }.joined()
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let record = PhotoRecord(
                id: photoId,
                babyIds: [babyStore.currentBabyId ?? "baby_e2e"],
                userId: "user_e2e",
                takenAt: now,
                sha256: sha256,
                filePath: fileURL.path,
                localOnly: true,
                updatedAt: now
            )

            await photoSource.upsert(record)
            try editStepsPersistence.save(editorState: editorState, photoId: photoId)

            if !savedPhotoIds.contains(photoId) {
                savedPhotoIds.insert(photoId)
                savedPhotoCount = savedPhotoIds.count
            }
            screen = .timeline
            statusMessage = offlineMode ? "离线保存成功" : "保存成功"
        } catch {
            statusMessage = "保存失败: \(error.localizedDescription)"
        }
    }

    func openTimeline() {
        screen = .timeline
    }

    func reEditPhoto(id: String) {
        do {
            let restored = try EditorState.restore(photoId: id, using: editStepsPersistence)
            editorStates[id] = restored
            toolbarBinding = EditorToolbarBinding()
            if baseImages[id] == nil {
                baseImages[id] = Self.makeMockCIImage(seed: id)
            }
            screen = .editor(photoId: id, isReEdit: true)
            statusMessage = "重新编辑 \(id)"
        } catch {
            statusMessage = "恢复编辑步骤失败"
        }
    }

    func finishReEditAndReturnToCamera(photoId: String) async {
        await savePhoto(photoId: photoId)
        completedCycles += 1
        screen = .mockCamera
        statusMessage = "完成第 \(completedCycles) 轮回归"
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
        throw P2E2EFlowError.missingBaseImage
    }

    private static func makeMockCIImage(seed: String) -> CIImage {
        let hash = seed.utf8.reduce(UInt8(0)) { ($0 &+ $1) }
        let red = CGFloat(hash % 200) / 255.0 + 0.2
        let green = CGFloat((hash / 3) % 200) / 255.0 + 0.2
        let blue = CGFloat((hash / 7) % 200) / 255.0 + 0.2
        return CIImage(color: CIColor(red: red, green: green, blue: blue))
            .cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))
    }
}

enum P2E2EFlowError: Error {
    case missingBaseImage
}

extension P2E2EFlowStore: PhotoEditorFlowManaging {
    var reEditCompleteButtonTitle: String { "保存并返回相机" }
}
