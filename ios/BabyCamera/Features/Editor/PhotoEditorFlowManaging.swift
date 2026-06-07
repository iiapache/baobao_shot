import BabyCameraEditor
import Foundation

/// 编辑器流程 Store 协议：P2 Harness 与主 App Tab 共用 `PhotoEditorFlowView`。
@MainActor
protocol PhotoEditorFlowManaging: AnyObject {
    var statusMessage: String { get }
    var toolbarBinding: EditorToolbarBinding { get set }
    var isSaving: Bool { get }
    var reEditCompleteButtonTitle: String { get }

    func applyCurrentFilter(to photoId: String)
    func savePhoto(photoId: String) async
    func finishReEditAndReturnToCamera(photoId: String) async
}
