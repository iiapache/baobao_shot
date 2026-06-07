import Foundation

/// Live Photo 配置与请求构建（design-ios §7.2：`livePhotoMovieFileURL`）。
public struct LivePhotoCapturer: Sendable {
    public let movieDirectory: URL
    private let fileManager: FileManager

    public init(movieDirectory: URL, fileManager: FileManager = .default) {
        self.movieDirectory = movieDirectory
        self.fileManager = fileManager
    }

    /// 在 PhotoOut 上启用 Live Photo 采集。
    public func configureOutput(_ output: any PhotoOutputControlling) throws {
        guard output.isLivePhotoCaptureSupported else {
            throw PhotoCaptureError.livePhotoUnsupported
        }
        output.isLivePhotoCaptureEnabled = true
    }

    /// 为单次 Live Photo 生成拍摄请求与配对视频临时路径。
    public func makeRequest(
        preferences: PhotoCapturePreferences,
        flashMode: CameraFlashMode = .auto
    ) throws -> PhotoCaptureRequest {
        try fileManager.createDirectory(at: movieDirectory, withIntermediateDirectories: true)
        let movieURL = movieDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension("mov")

        return PhotoCaptureRequest(
            format: preferences.preferredFormat,
            flashMode: flashMode,
            isLivePhoto: true,
            livePhotoMovieURL: movieURL
        )
    }
}
