import Foundation

public enum PhotosProviderFactory {
    public static func make(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useLiveOverride: Bool? = nil,
        permission: (any PhotosAddOnlyPermissionChecking)? = nil,
        writer: (any PhotosLibraryWriting)? = nil,
        ledger: (any PhotosWriteLedger)? = nil,
        albumTitle: String = PhotosProvider.defaultAlbumTitle
    ) -> PhotosProvider {
        let mode = DeviceLocalBackupConfiguration.resolvePhotosMode(
            bundle: bundle,
            forceStub: forceStub,
            useLiveOverride: useLiveOverride
        )
        switch mode {
        case .stub:
            return PhotosProvider(
                permission: permission ?? StubPhotosAddOnlyPermissionService(),
                writer: writer ?? StubPhotosLibraryWriter(),
                ledger: ledger ?? InMemoryPhotosWriteLedger(),
                albumTitle: albumTitle
            )
        case .live:
            return makeLiveProvider(
                permission: permission,
                writer: writer,
                ledger: ledger,
                albumTitle: albumTitle
            )
        }
    }

    public static func currentMode(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useLiveOverride: Bool? = nil
    ) -> DeviceLocalBackupMode {
        DeviceLocalBackupConfiguration.resolvePhotosMode(
            bundle: bundle,
            forceStub: forceStub,
            useLiveOverride: useLiveOverride
        )
    }

    private static func makeLiveProvider(
        permission: (any PhotosAddOnlyPermissionChecking)?,
        writer: (any PhotosLibraryWriting)?,
        ledger: (any PhotosWriteLedger)?,
        albumTitle: String
    ) -> PhotosProvider {
        #if canImport(Photos)
        return PhotosProvider(
            permission: permission ?? LivePhotosAddOnlyPermissionService(),
            writer: writer ?? LivePhotosLibraryWriter(),
            ledger: ledger ?? UserDefaultsPhotosWriteLedger(),
            albumTitle: albumTitle
        )
        #else
        return PhotosProvider(
            permission: permission ?? StubPhotosAddOnlyPermissionService(),
            writer: writer ?? StubPhotosLibraryWriter(),
            ledger: ledger ?? InMemoryPhotosWriteLedger(),
            albumTitle: albumTitle
        )
        #endif
    }
}
