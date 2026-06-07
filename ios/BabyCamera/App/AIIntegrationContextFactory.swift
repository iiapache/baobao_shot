import BabyCameraAccount
import BabyCameraAIPlay
import BabyCameraBaby
import BabyCameraCredit
import BabyCameraFamily
import BabyCameraNetwork
import Database
import Foundation

enum AIBootstrapError: LocalizedError {
    case missingFamily
    case missingBaby
    case missingSourcePhoto
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .missingFamily:
            return "未找到家庭，请先完成新手引导或加入家庭"
        case .missingBaby:
            return "未找到宝宝档案，请先创建宝宝"
        case .missingSourcePhoto:
            return "请先在相机 Tab 拍摄一张照片，再使用 AI 玩法"
        case .uploadFailed:
            return "上传 AI 输入图失败，请稍后重试"
        }
    }
}

/// App 层 AI 玩法联调上下文（NAV-07）。
struct AIIntegrationContext: @unchecked Sendable {
    let familyId: String
    let currentBaby: BabyProfile
    let sourcePhotoId: String
    let sourcePhotoFilePath: String
    let inputObjectKey: String
    let catalogService: PlayCatalogService
    let creditService: CreditService
    let taskCoordinator: AITaskCoordinator
    let downloadCoordinator: AITaskResultDownloadCoordinator
    let regionConfig: RegionConfig
    let urlSession: URLSession
}

/// 装配 AI 玩法目录、积分预览、任务协调与结果下载（FeedIntegrationContextFactory 模式）。
enum AIIntegrationContextFactory {
    struct BootstrapResult {
        let context: AIIntegrationContext
        let gridViewModel: AIPlayGridViewModel
    }

    @MainActor
    static func bootstrap(
        session: AuthSession,
        accountCoordinator: AccountCoordinator,
        appDatabase: AppDatabase,
        babyEnvironment: CurrentBabyEnvironment,
        familyId: String? = nil,
        region: AppRegion = .cn,
        urlSession: URLSession = NetworkSessionFactory.makeSession()
    ) async throws -> BootstrapResult {
        let tokenStore = accountCoordinator.authService.tokenStore
        let regionConfig = RegionConfig(
            region: region,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            deviceId: resolveDeviceId()
        )
        let useMockShortcuts = UITestBootstrap.isEnabled

        let resolvedFamilyId = try await resolveFamilyId(
            explicit: familyId,
            tokenStore: tokenStore,
            region: region,
            regionConfig: regionConfig,
            appDatabase: appDatabase,
            urlSession: urlSession
        )

        await MainTabBabyLoader.load(into: babyEnvironment, database: appDatabase)
        guard let currentBaby = babyEnvironment.currentBaby else {
            throw AIBootstrapError.missingBaby
        }

        let client = makeAuthenticatedClient(
            region: region,
            tokenStore: tokenStore,
            regionConfig: regionConfig,
            session: urlSession
        )

        let preparedInput = try await AIInputUploadHelper.prepare(
            babyId: currentBaby.id,
            userId: session.userId,
            appDatabase: appDatabase,
            client: client,
            useMockShortcuts: useMockShortcuts
        )

        let creditService = CreditService(
            configuration: CreditServiceConfiguration(
                region: region,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: urlSession
            )
        )

        let coordinatorConfiguration = AITaskCoordinator.Configuration(
            wsDisconnectPollingThreshold: useMockShortcuts ? 0.2 : 60,
            pollingInterval: useMockShortcuts ? 0.5 : 5
        )
        let taskCoordinator = LiveAITaskCoordinatorFactory.make(
            region: region,
            tokenStore: tokenStore,
            regionConfig: regionConfig,
            session: urlSession,
            configuration: coordinatorConfiguration,
            creditService: creditService
        )

        let storePaths = LocalStorePaths(storeRoot: MainTabStorePaths.storeRoot)
        let fileDownloader: any RemoteFileDownloading
        if useMockShortcuts, FileManager.default.fileExists(atPath: preparedInput.filePath) {
            fileDownloader = LocalCopyRemoteFileDownloader(sourcePath: preparedInput.filePath)
        } else {
            fileDownloader = URLSessionRemoteFileDownloader(session: urlSession)
        }

        let resultDownloader = AITaskResultDownloader(
            storePaths: storePaths,
            fileDownloader: fileDownloader,
            aiTaskRepository: appDatabase.makeAITaskLocalRepository(),
            derivedRepository: appDatabase.makeDerivedRepository()
        )
        let downloadCoordinator = AITaskResultDownloadCoordinator(downloader: resultDownloader)
        await downloadCoordinator.startObserving(taskCoordinator)

        let catalogService = PlayCatalogService(
            configuration: PlayCatalogServiceConfiguration(
                region: region,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: urlSession
            )
        )

        let context = AIIntegrationContext(
            familyId: resolvedFamilyId,
            currentBaby: currentBaby,
            sourcePhotoId: preparedInput.photoId,
            sourcePhotoFilePath: preparedInput.filePath,
            inputObjectKey: preparedInput.objectKey,
            catalogService: catalogService,
            creditService: creditService,
            taskCoordinator: taskCoordinator,
            downloadCoordinator: downloadCoordinator,
            regionConfig: regionConfig,
            urlSession: urlSession
        )

        let gridViewModel = AIPlayGridViewModel(catalogService: catalogService)
        return BootstrapResult(context: context, gridViewModel: gridViewModel)
    }

    private static func resolveFamilyId(
        explicit: String?,
        tokenStore: TokenStore,
        region: AppRegion,
        regionConfig: RegionConfig,
        appDatabase: AppDatabase,
        urlSession: URLSession
    ) async throws -> String {
        if let explicit, !explicit.isEmpty {
            return explicit
        }

        let familyRepository = appDatabase.makeFamilyRepository()
        let localFamilies = try await familyRepository.fetchAll()
        if let first = localFamilies.first {
            return first.id
        }

        let babyRepository = appDatabase.makeBabyRepository()
        if let babyId = UserDefaults.standard.string(forKey: "com.babycamera.currentBabyId"),
           let baby = try await babyRepository.fetch(id: babyId) {
            return baby.familyId
        }

        let familyService = FamilyService(
            configuration: FamilyServiceConfiguration(
                region: region,
                regionConfig: regionConfig,
                tokenStore: tokenStore,
                session: urlSession
            )
        )
        let families = try await familyService.listFamilies()
        guard let first = families.first else {
            throw AIBootstrapError.missingFamily
        }
        return first.id
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

enum MainTabStorePaths {
    static var storeRoot: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BabyCameraStore", isDirectory: true)
    }
}
