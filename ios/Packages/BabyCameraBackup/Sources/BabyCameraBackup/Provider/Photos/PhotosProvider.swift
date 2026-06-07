import Foundation

/// 系统相册备份：仅 `addOnly` 权限，双写至专用相册；不读取用户相册（T6.4 stub）。
public struct PhotosProvider: BackupProvider, Sendable {
    public static let defaultAlbumTitle = "宝宝成长相机"
    public static let listPageSize = 100

    public let kind: BackupKind = .photos

    private let permission: any PhotosAddOnlyPermissionChecking
    private let writer: any PhotosLibraryWriting
    private let ledger: any PhotosWriteLedger
    private let albumTitle: String
    private let clock: @Sendable () -> Int64

    public init(
        permission: any PhotosAddOnlyPermissionChecking,
        writer: any PhotosLibraryWriting = StubPhotosLibraryWriter(),
        ledger: any PhotosWriteLedger = InMemoryPhotosWriteLedger(),
        albumTitle: String = PhotosProvider.defaultAlbumTitle,
        clock: @escaping @Sendable () -> Int64 = {
            Int64(Date().timeIntervalSince1970 * 1_000)
        }
    ) {
        self.permission = permission
        self.writer = writer
        self.ledger = ledger
        self.albumTitle = albumTitle
        self.clock = clock
    }

    public func authorize() async throws {
        let status = permission.authorizationStatus()
        let resolved: PhotosAddOnlyAuthorizationStatus
        if status == .notDetermined {
            resolved = await permission.requestAuthorization()
        } else {
            resolved = status
        }

        switch resolved {
        case .authorized:
            return
        case .denied:
            throw PhotosProviderError.authorizationDenied
        case .restricted:
            throw PhotosProviderError.authorizationRestricted
        case .notDetermined:
            throw PhotosProviderError.authorizationDenied
        }
    }

    public func quota() async throws -> BackupQuota {
        let usedBytes = await ledger.totalUsedBytes()
        return BackupQuota(usedBytes: usedBytes, totalBytes: nil)
    }

    public func upload(_ item: BackupItem) async throws -> BackupReceipt {
        try await authorize()

        let fileURL = URL(fileURLWithPath: item.filePath)
        let writeResult = try await writer.writeImage(from: fileURL, albumTitle: albumTitle)
        let remoteItem = BackupRemoteItem(remoteId: writeResult.assetLocalIdentifier, sha256: item.sha256)
        await ledger.record(item: remoteItem, byteSize: writeResult.byteSize)

        return BackupReceipt(
            remoteId: writeResult.assetLocalIdentifier,
            sha256: item.sha256,
            uploadedAt: clock()
        )
    }

    public func list(after cursor: String?) async throws -> BackupPage {
        // 仅返回本 Provider 写入台账；不查询用户相册。
        await ledger.page(after: cursor, limit: Self.listPageSize)
    }

    public func revoke() async throws {
        await ledger.clear()
    }
}

#if canImport(Photos)
extension PhotosProvider {
    public static func live(
        writer: any PhotosLibraryWriting = StubPhotosLibraryWriter(),
        ledger: any PhotosWriteLedger = InMemoryPhotosWriteLedger(),
        albumTitle: String = PhotosProvider.defaultAlbumTitle
    ) -> PhotosProvider {
        PhotosProvider(
            permission: LivePhotosAddOnlyPermissionService(),
            writer: writer,
            ledger: ledger,
            albumTitle: albumTitle
        )
    }
}
#endif
