import BabyCameraBaby
import BabyCameraCamera
import BabyCameraDiagnostics
import SwiftUI
import UIKit

/// SwiftUI 包装 `CameraViewController`，快门回调触发拍摄入库。
struct CameraViewRepresentable: UIViewControllerRepresentable {
    @ObservedObject var captureStore: CameraCaptureStore
    let overlayInfo: CameraOverlayInfo?
    let userId: String
    let baby: BabyProfile

    func makeCoordinator() -> Coordinator {
        Coordinator(
            captureStore: captureStore,
            userId: userId,
            baby: baby
        )
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController(session: captureStore.session)
        controller.onCaptureRequested = { [weak coordinator = context.coordinator] in
            coordinator?.handleCapture(overlayInfo: overlayInfo)
        }
        controller.onStartupCompleted = { elapsed in
            _ = PerformanceTracker.recordCameraColdStart(
                elapsedSeconds: elapsed,
                source: "camera_tab"
            )
        }
        controller.updateOverlayInfo(overlayInfo)
        context.coordinator.viewController = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.updateOverlayInfo(overlayInfo)
        context.coordinator.baby = baby
        context.coordinator.userId = userId
    }

    @MainActor
    final class Coordinator {
        let captureStore: CameraCaptureStore
        var userId: String
        var baby: BabyProfile
        weak var viewController: CameraViewController?

        init(captureStore: CameraCaptureStore, userId: String, baby: BabyProfile) {
            self.captureStore = captureStore
            self.userId = userId
            self.baby = baby
        }

        func handleCapture(overlayInfo: CameraOverlayInfo?) {
            Task { @MainActor in
                await captureStore.capturePhoto(
                    userId: userId,
                    baby: baby,
                    overlayInfo: overlayInfo ?? viewController?.overlayInfo
                )
            }
        }
    }
}
