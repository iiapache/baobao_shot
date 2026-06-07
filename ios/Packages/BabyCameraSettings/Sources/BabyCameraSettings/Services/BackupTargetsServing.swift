import BabyCameraBackup
import BabyCameraNetwork
import Foundation

public struct BackupTargetItem: Identifiable, Equatable, Sendable {
    public let kind: BackupKind
    public let provider: BackupProviderData?

    public var id: String { kind.rawValue }

    public init(kind: BackupKind, provider: BackupProviderData?) {
        self.kind = kind
        self.provider = provider
    }

    public var isBound: Bool {
        guard let provider else { return false }
        return provider.status == "active"
    }
}

/// 备份目标 list/bind/unbind 抽象，便于 mock 测试。
public protocol BackupTargetsServing: Sendable {
    func listTargets() async throws -> [BackupTargetItem]
    func bindTarget(_ kind: BackupKind) async throws -> BackupProviderData
    func unbindTarget(_ kind: BackupKind) async throws
    func backupStatus() async throws -> BackupStatusData
}

public struct BackupTargetsService: BackupTargetsServing {
    private let api: BackupAPI

    public init(api: BackupAPI) {
        self.api = api
    }

    public func listTargets() async throws -> [BackupTargetItem] {
        let response = try await api.listProviders()
        let providersByKind = Dictionary(
            uniqueKeysWithValues: response.items.compactMap { provider in
                guard let kind = BackupKind(apiKindValue: provider.kind) else { return nil }
                return (kind, provider)
            }
        )
        return BackupKind.allCases.map { kind in
            BackupTargetItem(kind: kind, provider: providersByKind[kind])
        }
    }

    public func bindTarget(_ kind: BackupKind) async throws -> BackupProviderData {
        try await api.bindProvider(Self.bindRequest(for: kind))
    }

    public func unbindTarget(_ kind: BackupKind) async throws {
        let targets = try await listTargets()
        guard let provider = targets.first(where: { $0.kind == kind })?.provider else {
            return
        }
        _ = try await api.unbindProvider(id: provider.id)
    }

    public func backupStatus() async throws -> BackupStatusData {
        try await api.getStatus()
    }

    private static func bindRequest(for kind: BackupKind) -> BindBackupProviderRequest {
        BindBackupProviderRequest(
            kind: kind.apiKindValue,
            accessToken: "device-local",
            metadata: ["platform": "ios", "binding": "settings"]
        )
    }
}
