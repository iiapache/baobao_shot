import BabyCameraAccount
import BabyCameraFamily
import BabyCameraNetwork
import BabyCameraNotification
import BabyCameraPermissions
import Database
import Foundation

/// App 层联调工厂（T6.10 / T6.14）。
public enum SettingsIntegrationContextFactory {
    public static func make(
        session: AuthSession,
        accountCoordinator: AccountCoordinator,
        appDatabase: AppDatabase,
        familyId: String? = nil,
        region: AppRegion = .cn
    ) -> SettingsIntegrationContext {
        let tokenStore = accountCoordinator.authService.tokenStore
        let regionConfig = RegionConfig(
            region: region,
            appVersion: AppVersionInfo.fromBundle().marketingVersion,
            deviceId: resolveDeviceId()
        )
        let client = makeAuthenticatedClient(
            region: region,
            tokenStore: tokenStore,
            regionConfig: regionConfig
        )

        return SettingsIntegrationContext(
            session: session,
            familyId: familyId,
            appDatabase: appDatabase,
            accountCoordinator: accountCoordinator,
            familyService: FamilyService(
                configuration: FamilyServiceConfiguration(
                    region: region,
                    regionConfig: regionConfig,
                    tokenStore: tokenStore
                )
            ),
            notificationService: NotificationService(
                configuration: NotificationServiceConfiguration(
                    region: region,
                    regionConfig: regionConfig,
                    tokenStore: tokenStore
                )
            ),
            complianceService: ComplianceConfigService(client: client, region: region),
            permissionManager: DefaultPermissionManager()
        )
    }

    private static func resolveDeviceId() -> String {
        let key = "com.babycamera.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}
