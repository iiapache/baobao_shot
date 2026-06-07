import BabyCameraAccount
import BabyCameraCredit
import BabyCameraNetwork
import BabyCameraSettings
import Foundation

/// App 层「我的」Tab 联调工厂（NAV-08）：积分 / 订阅 / IAP 与 AccountCoordinator 共享 TokenStore。
enum ProfileIntegrationContextFactory {
    struct Services {
        let creditService: CreditService
        let subscriptionStore: SubscriptionStore
        let iapService: IAPService
        let adManager: AdManager
    }

    static func make(
        accountCoordinator: AccountCoordinator,
        region: AppRegion = .cn,
        urlSession: URLSession = NetworkSessionFactory.makeSession()
    ) -> Services {
        let tokenStore = accountCoordinator.authService.tokenStore
        let regionConfig = RegionConfig(
            region: region,
            appVersion: AppVersionInfo.fromBundle().marketingVersion,
            deviceId: resolveDeviceId()
        )

        let creditService = CreditService(
            configuration: CreditServiceConfiguration(
                region: region,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: urlSession
            )
        )

        let storeClient = IAPStoreClientFactory.make(
            forceStub: UITestBootstrap.isEnabled
        )

        let appAttestProvider = AppAttestAttachmentProviders.makeDefault(
            forceStub: UITestBootstrap.isEnabled
        )

        let subscriptionStore = SubscriptionStore(
            configuration: SubscriptionStoreConfiguration(
                region: region,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: urlSession,
                appAttestAttachmentProvider: appAttestProvider
            ),
            storeClient: storeClient
        )

        let iapService = IAPService(
            configuration: IAPServiceConfiguration(
                region: region,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: urlSession,
                appAttestAttachmentProvider: appAttestProvider
            ),
            storeClient: storeClient
        )

        let adManager = AdManagerFactory.make(
            region: region,
            regionConfig: regionConfig,
            tokenStore: tokenStore,
            session: urlSession,
            isSubscribed: { !subscriptionStore.shouldShowAds },
            forceStub: UITestBootstrap.isEnabled
        )
        adManager.bindCreditService(creditService)

        return Services(
            creditService: creditService,
            subscriptionStore: subscriptionStore,
            iapService: iapService,
            adManager: adManager
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
