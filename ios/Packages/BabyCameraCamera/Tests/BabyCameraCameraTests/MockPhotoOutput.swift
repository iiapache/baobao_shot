import Foundation
@testable import BabyCameraCamera

/// 单测用 PhotoOut mock，不依赖真机 AVCapture。
final class MockPhotoOutput: PhotoOutputControlling, @unchecked Sendable {
    var isLivePhotoCaptureSupported = true
    var isLivePhotoCaptureEnabled = false

    var captureCallCount = 0
    var lastRequest: PhotoCaptureRequest?
    var simulatedLatency: TimeInterval = 0.05
    var imageDataProvider: (() -> Data)?
    var shouldFail = false
    var configuredForLivePhoto = false

    func capturePhoto(
        request: PhotoCaptureRequest,
        completion: @escaping @Sendable (Result<RawPhotoCapture, PhotoCaptureError>) -> Void
    ) {
        captureCallCount += 1
        lastRequest = request

        let work = {
            if self.shouldFail {
                completion(.failure(.captureFailed))
                return
            }
            if request.isLivePhoto && !self.isLivePhotoCaptureSupported {
                completion(.failure(.livePhotoUnsupported))
                return
            }
            guard let data = self.imageDataProvider?(), !data.isEmpty else {
                completion(.failure(.captureFailed))
                return
            }
            completion(
                .success(
                    RawPhotoCapture(
                        imageData: data,
                        livePhotoMovieURL: request.livePhotoMovieURL,
                        capturedAt: Date()
                    )
                )
            )
        }

        if simulatedLatency > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + simulatedLatency, execute: work)
        } else {
            work()
        }
    }
}

/// 单测用会话预设 mock。
final class MockSessionPresetController: SessionPresetControlling, @unchecked Sendable {
    var currentSessionPreset: AVCaptureSession.Preset = .photo
    var presetChanges: [AVCaptureSession.Preset] = []
    var shouldFail = false

    func setSessionPreset(_ preset: AVCaptureSession.Preset) throws {
        if shouldFail { throw PhotoCaptureError.sessionPresetUnavailable }
        currentSessionPreset = preset
        presetChanges.append(preset)
    }
}

/// 单测用零延迟时钟。
struct ImmediateBurstClock: BurstClock {
    func sleep(for interval: TimeInterval) async throws {}
}
