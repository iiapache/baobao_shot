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

/// Debug / UI 测试：默认已授权，不弹出系统权限对话框。
public struct StubPhotosAddOnlyPermissionService: PhotosAddOnlyPermissionChecking {
    public var status: PhotosAddOnlyAuthorizationStatus

    public init(status: PhotosAddOnlyAuthorizationStatus = .authorized) {
        self.status = status
    }

    public func authorizationStatus() -> PhotosAddOnlyAuthorizationStatus {
        status
    }

    public func requestAuthorization() async -> PhotosAddOnlyAuthorizationStatus {
        status
    }
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

/// Debug / UI 测试：不调用 Photos 写入 API，仅校验文件并生成确定性 asset id。
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

#if canImport(Photos)
/// 真机 PhotoKit 写入：addOnly 权限下写入专用相册，不读取用户相册。
public struct LivePhotosLibraryWriter: PhotosLibraryWriting {
    public init() {}

    public func writeImage(from fileURL: URL, albumTitle: String) async throws -> PhotosWriteResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw PhotosProviderError.fileNotFound(path: fileURL.path)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let byteSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        return try await withCheckedThrowingContinuation { continuation in
            var createdAssetID: String?

            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, fileURL: fileURL, options: nil)
                guard let placeholder = creationRequest.placeholderForCreatedAsset else { return }
                createdAssetID = placeholder.localIdentifier

                let collections = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .albumRegular,
                    options: nil
                )
                var existingAlbum: PHAssetCollection?
                collections.enumerateObjects { collection, _, stop in
                    if collection.localizedTitle == albumTitle {
                        existingAlbum = collection
                        stop.pointee = true
                    }
                }

                if let existingAlbum,
                   let changeRequest = PHAssetCollectionChangeRequest(for: existingAlbum) {
                    changeRequest.addAssets([placeholder] as NSArray)
                } else {
                    let albumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                        withTitle: albumTitle
                    )
                    albumRequest.addAssets([placeholder] as NSArray)
                }
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(
                        throwing: PhotosProviderError.writeFailed(reason: error.localizedDescription)
                    )
                    return
                }
                guard success, let assetID = createdAssetID else {
                    continuation.resume(
                        throwing: PhotosProviderError.writeFailed(reason: "Photos write did not return asset id")
                    )
                    return
                }
                continuation.resume(
                    returning: PhotosWriteResult(assetLocalIdentifier: assetID, byteSize: byteSize)
                )
            }
        }
    }
}
#endif
