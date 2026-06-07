import Foundation
#if canImport(Photos)
import Photos
#endif

// MARK: - Authorization

public enum PhotosAddOnlyAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public protocol PhotosAddOnlyPermissionChecking: Sendable {
    func authorizationStatus() -> PhotosAddOnlyAuthorizationStatus
    func requestAuthorization() async -> PhotosAddOnlyAuthorizationStatus
}

#if canImport(Photos)
public struct LivePhotosAddOnlyPermissionService: PhotosAddOnlyPermissionChecking {
    public static let accessLevel: PHAccessLevel = .addOnly

    public init() {}

    public func authorizationStatus() -> PhotosAddOnlyAuthorizationStatus {
        Self.map(PHPhotoLibrary.authorizationStatus(for: Self.accessLevel))
    }

    public func requestAuthorization() async -> PhotosAddOnlyAuthorizationStatus {
        Self.map(await PHPhotoLibrary.requestAuthorization(for: Self.accessLevel))
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotosAddOnlyAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized, .limited:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
}
#endif

// MARK: - Library write

public struct PhotosWriteResult: Sendable, Equatable {
    public let assetLocalIdentifier: String
    public let byteSize: Int64

    public init(assetLocalIdentifier: String, byteSize: Int64) {
        self.assetLocalIdentifier = assetLocalIdentifier
        self.byteSize = byteSize
    }
}

public protocol PhotosLibraryWriting: Sendable {
    func writeImage(from fileURL: URL, albumTitle: String) async throws -> PhotosWriteResult
}

/// T6.4 Live 占位：不调用 Photos 写入 API，仅校验文件并生成确定性 asset id。
public struct StubPhotosLibraryWriter: PhotosLibraryWriting {
    public init() {}

    public func writeImage(from fileURL: URL, albumTitle: String) async throws -> PhotosWriteResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw PhotosProviderError.fileNotFound(path: fileURL.path)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let byteSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let assetID = "stub-photos-\(fileURL.lastPathComponent)"

        return PhotosWriteResult(assetLocalIdentifier: assetID, byteSize: byteSize)
    }
}
