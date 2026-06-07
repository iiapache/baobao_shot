import Foundation

/// 拍摄管线错误。
public enum PhotoCaptureError: Error, Equatable, Sendable {
    case outputUnavailable
    case captureInProgress
    case captureFailed
    case encodingFailed
    case writeFailed
    case livePhotoUnsupported
    case burstNotActive
    case sessionPresetUnavailable
}
