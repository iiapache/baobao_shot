import BabyCameraAccount
import BabyCameraBackup
import BabyCameraFamily
import BabyCameraNetwork
import BabyCameraNotification
import BabyCameraPermissions
import Database
import XCTest
@testable import BabyCameraSettings

@MainActor
final class SettingsIntegrationContextTests: XCTestCase {
    func testMakeFamilyMembersViewModelReturnsNilWithoutFamilyId() throws {
        let context = try makeContext(familyId: nil)
        XCTAssertNil(context.makeFamilyMembersViewModel())
    }

    func testMakeFamilyMembersViewModelWithFamilyId() throws {
        let context = try makeContext(familyId: "fam_001")
        let viewModel = context.makeFamilyMembersViewModel()
        XCTAssertEqual(viewModel?.familyId, "fam_001")
    }

    func testMakeNotificationCategoryStore() throws {
        let context = try makeContext(familyId: nil)
        let store = context.makeNotificationCategoryStore()
        XCTAssertFalse(store.categories.isEmpty)
    }

    func testLiveFactoryWiresNotificationService() throws {
        let appDatabase = try AppDatabase.makeInMemory()
        let tokenStore = InMemoryTokenStore()
        let authService = AuthService(
            configuration: AuthServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            )
        )
        let coordinator = AccountCoordinator(authService: authService)
        let context = SettingsIntegrationContextFactory.make(
            session: AuthSession(userId: "usr_1", isNewUser: false, profile: nil),
            accountCoordinator: coordinator,
            appDatabase: appDatabase
        )

        let store = context.makeNotificationCategoryStore()
        XCTAssertTrue(store.notificationService is NotificationService)
    }

    func testMakeDataExportViewModelReturnsNilWithoutFamilyId() throws {
        let context = try makeContext(familyId: nil)
        XCTAssertNil(context.makeDataExportViewModel())
    }

    func testMakeDataExportViewModelWithFamilyId() throws {
        let context = try makeContext(familyId: "fam_001")
        XCTAssertNotNil(context.makeDataExportViewModel())
    }

    func testMakeFeedbackViewModelUsesSessionAndSupportEmail() throws {
        let context = try makeContext(
            familyId: nil,
            supportEmail: "support@example.com"
        )
        let viewModel = context.makeFeedbackViewModel()

        XCTAssertEqual(viewModel.service.validate(
            submission: FeedbackSubmission(category: .bug, description: "test")
        ), .valid)
    }

    func testMakeUninstallReminderStore() throws {
        let context = try makeContext(familyId: nil)
        let store = context.makeUninstallReminderStore()
        XCTAssertFalse(store.enabled)
    }

    func testMakeCacheCleanupViewModel() throws {
        let context = try makeContext(familyId: nil)
        XCTAssertNotNil(context.makeCacheCleanupViewModel())
    }

    func testMakeBackupTargetsViewModelReturnsNilWithoutService() throws {
        let context = try makeContext(familyId: nil)
        XCTAssertNil(context.makeBackupTargetsViewModel())
    }

    func testMakeBackupTargetsViewModelWithService() throws {
        let context = try makeContext(
            familyId: nil,
            backupTargetsService: MockBackupTargetsServiceForContext()
        )
        XCTAssertNotNil(context.makeBackupTargetsViewModel())
    }

    private func makeContext(
        familyId: String?,
        supportEmail: String = FeedbackSupportEmailResolver.defaultEmail,
        backupTargetsService: (any BackupTargetsServing)? = nil
    ) throws -> SettingsIntegrationContext {
        let appDatabase = try AppDatabase.makeInMemory()
        let tokenStore = InMemoryTokenStore()
        let authService = AuthService(
            configuration: AuthServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession()
            )
        )
        return SettingsIntegrationContext(
            session: AuthSession(userId: "usr_1", isNewUser: false, profile: nil),
            familyId: familyId,
            appDatabase: appDatabase,
            accountCoordinator: AccountCoordinator(authService: authService),
            familyService: FamilyService(
                configuration: FamilyServiceConfiguration(
                    region: .cn,
                    regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                    tokenStore: tokenStore,
                    session: MockURLProtocol.makeSession()
                )
            ),
            notificationService: MockNotificationService(),
            complianceService: MockComplianceConfigService(),
            permissionManager: DefaultPermissionManager(),
            supportEmail: supportEmail,
            backupTargetsService: backupTargetsService
        )
    }
}

private struct MockBackupTargetsServiceForContext: BackupTargetsServing {
    func listTargets() async throws -> [BackupTargetItem] {
        BackupKind.allCases.map { BackupTargetItem(kind: $0, provider: nil) }
    }

    func bindTarget(_ kind: BackupKind) async throws -> BackupProviderData {
        BackupProviderData(
            id: "bkp_test",
            kind: kind.apiKindValue,
            status: "active",
            createdAt: "2026-06-01T00:00:00Z",
            updatedAt: "2026-06-01T00:00:00Z"
        )
    }

    func unbindTarget(_ kind: BackupKind) async throws {}

    func backupStatus() async throws -> BackupStatusData {
        BackupStatusData()
    }
}

private struct MockComplianceConfigService: ComplianceConfigServing {
    func fetchComplianceConfig() async throws -> ComplianceConfig {
        ComplianceConfig.defaults(for: .cn)
    }
}

@MainActor
private final class MockNotificationService: NotificationServing {
    var unreadCount: Int { 0 }

    func refreshUnreadCount() async throws {}
    func listNotifications(cursor: String?) async throws -> NotificationListData {
        NotificationListData(items: [], unreadCount: 0)
    }
    func markAllRead() async throws -> MarkNotificationsReadData {
        MarkNotificationsReadData(markedCount: 0, unreadCount: 0)
    }
    func loadCategorySubscriptions() async throws -> [NotificationCategory] {
        NotificationCategory.allDefaults
    }
    func updateCategory(_ category: NotificationCategoryCode, enabled: Bool) async throws -> [NotificationCategory] {
        NotificationCategory.allDefaults
    }
}
