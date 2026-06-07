import BabyCameraBackup
import BabyCameraNetwork
import DesignSystem
import XCTest
@testable import BabyCameraSettings

final class BackupTargetsManagementTests: XCTestCase {
    func testListTargetsMapsAllKinds() async throws {
        let service = MockBackupTargetsService(
            providers: [
                makeProvider(id: "bkp_1", kind: "icloud"),
                makeProvider(id: "bkp_2", kind: "baidu_pan"),
            ],
            status: BackupStatusData(lastSuccessAt: "2026-06-01T10:00:00Z")
        )

        let targets = try await service.listTargets()
        XCTAssertEqual(targets.count, BackupKind.allCases.count)
        XCTAssertTrue(targets.first(where: { $0.kind == .iCloud })?.isBound == true)
        XCTAssertTrue(targets.first(where: { $0.kind == .baiduPan })?.isBound == true)
        XCTAssertFalse(targets.first(where: { $0.kind == .photos })?.isBound == true)
    }

    func testBindTargetAddsProvider() async throws {
        let service = MockBackupTargetsService()
        let provider = try await service.bindTarget(.photos)

        XCTAssertEqual(provider.kind, "photos")
        XCTAssertEqual(service.bindCalls, [.photos])
        let targets = try await service.listTargets()
        XCTAssertTrue(targets.first(where: { $0.kind == .photos })?.isBound == true)
    }

    func testUnbindTargetRemovesProvider() async throws {
        let service = MockBackupTargetsService(
            providers: [makeProvider(id: "bkp_icloud", kind: "icloud")]
        )

        try await service.unbindTarget(.iCloud)
        XCTAssertEqual(service.unbindCalls, [.iCloud])

        let targets = try await service.listTargets()
        XCTAssertFalse(targets.first(where: { $0.kind == .iCloud })?.isBound == true)
    }

    @MainActor
    func testViewModelRefreshLoadsStatusSummary() async throws {
        let service = MockBackupTargetsService(
            providers: [makeProvider(id: "bkp_1", kind: "icloud")],
            status: BackupStatusData(
                lastSuccessAt: "2026-06-01T08:30:00Z",
                failureCount: 0
            )
        )
        let viewModel = BackupTargetsManagementViewModel(service: service)

        await viewModel.refresh()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.targets.first(where: { $0.kind == .iCloud })?.isBound == true)
        XCTAssertNotNil(viewModel.statusSummary)
        XCTAssertNotEqual(viewModel.statusSummary?.statusLabel, L10n.string("settings.backup.status.never"))
    }

    @MainActor
    func testViewModelSetEnabledBindsAndUnbinds() async throws {
        let service = MockBackupTargetsService()
        let viewModel = BackupTargetsManagementViewModel(service: service)

        await viewModel.setEnabled(.photos, enabled: true)
        XCTAssertTrue(viewModel.targets.first(where: { $0.kind == .photos })?.isBound == true)

        await viewModel.setEnabled(.photos, enabled: false)
        XCTAssertFalse(viewModel.targets.first(where: { $0.kind == .photos })?.isBound == true)
    }

    private func makeProvider(id: String, kind: String) -> BackupProviderData {
        BackupProviderData(
            id: id,
            kind: kind,
            status: "active",
            createdAt: "2026-06-01T00:00:00Z",
            updatedAt: "2026-06-01T00:00:00Z"
        )
    }
}

private final class MockBackupTargetsService: BackupTargetsServing, @unchecked Sendable {
    private var providers: [BackupProviderData]
    private let status: BackupStatusData
    private(set) var bindCalls: [BackupKind] = []
    private(set) var unbindCalls: [BackupKind] = []

    init(
        providers: [BackupProviderData] = [],
        status: BackupStatusData = BackupStatusData()
    ) {
        self.providers = providers
        self.status = status
    }

    func listTargets() async throws -> [BackupTargetItem] {
        let providersByKind = Dictionary(
            uniqueKeysWithValues: providers.compactMap { provider in
                guard let kind = BackupKind(apiKindValue: provider.kind) else { return nil }
                return (kind, provider)
            }
        )
        return BackupKind.allCases.map { kind in
            BackupTargetItem(kind: kind, provider: providersByKind[kind])
        }
    }

    func bindTarget(_ kind: BackupKind) async throws -> BackupProviderData {
        bindCalls.append(kind)
        let provider = BackupProviderData(
            id: "bkp_\(kind.rawValue)",
            kind: kind.apiKindValue,
            status: "active",
            createdAt: "2026-06-01T00:00:00Z",
            updatedAt: "2026-06-01T00:00:00Z"
        )
        providers.removeAll { BackupKind(apiKindValue: $0.kind) == kind }
        providers.append(provider)
        return provider
    }

    func unbindTarget(_ kind: BackupKind) async throws {
        unbindCalls.append(kind)
        providers.removeAll { BackupKind(apiKindValue: $0.kind) == kind }
    }

    func backupStatus() async throws -> BackupStatusData {
        status
    }
}
