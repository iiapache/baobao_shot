import Foundation

public enum ICloudProviderFactory {
    public static func make(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useLiveOverride: Bool? = nil,
        database: (any CloudKitPrivateDatabaseProviding)? = nil,
        clock: any BackupClock = SystemBackupClock()
    ) -> ICloudProvider {
        let mode = DeviceLocalBackupConfiguration.resolveICloudMode(
            bundle: bundle,
            forceStub: forceStub,
            useLiveOverride: useLiveOverride
        )
        switch mode {
        case .stub:
            return ICloudProvider(
                database: database ?? StubCloudKitPrivateDatabase(),
                clock: clock
            )
        case .live:
            let containerID = DeviceLocalBackupConfiguration.iCloudContainerIdentifierFromInfoPlist(bundle: bundle)
            return ICloudProvider(
                database: database ?? LiveCloudKitPrivateDatabase(
                    containerIdentifier: containerID,
                    clock: clock
                ),
                clock: clock
            )
        }
    }

    public static func currentMode(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useLiveOverride: Bool? = nil
    ) -> DeviceLocalBackupMode {
        DeviceLocalBackupConfiguration.resolveICloudMode(
            bundle: bundle,
            forceStub: forceStub,
            useLiveOverride: useLiveOverride
        )
    }
}
