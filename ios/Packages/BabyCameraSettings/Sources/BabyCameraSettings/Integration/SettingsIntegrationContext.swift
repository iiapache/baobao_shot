import BabyCameraAccount
import BabyCameraBackup
import BabyCameraFamily
import BabyCameraNetwork
import BabyCameraNotification
import BabyCameraPermissions
import Database
import Foundation

/// T6.10 设置中心联调上下文。
public struct SettingsIntegrationContext {
    public let session: AuthSession
    public let familyId: String?
    public let appDatabase: AppDatabase
    public let accountCoordinator: AccountCoordinator
    public let familyService: FamilyService
    public let notificationService: any NotificationServing
    public let complianceService: any ComplianceConfigServing
    public let permissionManager: any PermissionManager
    public let versionInfo: AppVersionInfo
    public let dataExportScheduler: any DataExportBackgroundScheduling
    public let uninstallReminderCoordinator: UninstallReminderCoordinator
    public let feedbackLogProvider: any FeedbackLogProviding
    public let supportEmail: String
    public let thumbnailCache: any ThumbnailCacheManaging
    public let backupTargetsService: (any BackupTargetsServing)?

    public init(
        session: AuthSession,
        familyId: String?,
        appDatabase: AppDatabase,
        accountCoordinator: AccountCoordinator,
        familyService: FamilyService,
        notificationService: any NotificationServing,
        complianceService: any ComplianceConfigServing,
        permissionManager: any PermissionManager,
        versionInfo: AppVersionInfo = .fromBundle(),
        dataExportScheduler: any DataExportBackgroundScheduling = InMemoryDataExportBackgroundScheduler(),
        uninstallReminderCoordinator: UninstallReminderCoordinator = UninstallReminderCoordinator(),
        feedbackLogProvider: any FeedbackLogProviding = FeedbackDiagnosticLogProvider(),
        supportEmail: String = FeedbackSupportEmailResolver.defaultEmail,
        thumbnailCache: any ThumbnailCacheManaging = LiveThumbnailCacheManaging(),
        backupTargetsService: (any BackupTargetsServing)? = nil
    ) {
        self.session = session
        self.familyId = familyId
        self.appDatabase = appDatabase
        self.accountCoordinator = accountCoordinator
        self.familyService = familyService
        self.notificationService = notificationService
        self.complianceService = complianceService
        self.permissionManager = permissionManager
        self.versionInfo = versionInfo
        self.dataExportScheduler = dataExportScheduler
        self.uninstallReminderCoordinator = uninstallReminderCoordinator
        self.feedbackLogProvider = feedbackLogProvider
        self.supportEmail = supportEmail
        self.thumbnailCache = thumbnailCache
        self.backupTargetsService = backupTargetsService
    }

    public func makeNotificationCategoryStore() -> NotificationCategoryStore {
        NotificationCategoryStore(notificationService: notificationService)
    }

    public func makeFamilyMembersViewModel() -> FamilyMembersViewModel? {
        guard let familyId else { return nil }
        return FamilyMembersViewModel(familyId: familyId, familyService: familyService)
    }

    public func makeDataExportViewModel() -> DataExportViewModel? {
        guard let familyId else { return nil }
        let exportService = DataExportService(
            babyRepository: appDatabase.makeBabyRepository(),
            photoRepository: appDatabase.makePhotoRepository(),
            milestoneRepository: appDatabase.makeMilestoneRepository(),
            metadataBuilder: DataExportMetadataBuilder(appVersion: versionInfo.marketingVersion)
        )
        let coordinator = DataExportBackgroundCoordinator(
            exportService: exportService,
            scheduler: dataExportScheduler
        )
        return DataExportViewModel(coordinator: coordinator, familyId: familyId)
    }

    @MainActor
    public func makeUninstallReminderStore() -> UninstallReminderStore {
        UninstallReminderStore(coordinator: uninstallReminderCoordinator)
    }

    public func makeFeedbackViewModel() -> FeedbackViewModel {
        let service = FeedbackService(
            supportEmail: supportEmail,
            versionInfo: versionInfo,
            userId: session.userId,
            logProvider: feedbackLogProvider
        )
        return FeedbackViewModel(service: service)
    }

    public func makeCacheCleanupViewModel() -> CacheCleanupViewModel {
        CacheCleanupViewModel(
            service: CacheCleanupService(thumbnailCache: thumbnailCache)
        )
    }

    public func makeBackupTargetsViewModel() -> BackupTargetsManagementViewModel? {
        guard let backupTargetsService else { return nil }
        return BackupTargetsManagementViewModel(service: backupTargetsService)
    }
}
