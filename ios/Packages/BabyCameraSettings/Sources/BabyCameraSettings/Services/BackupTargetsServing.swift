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
    private let baiduPanProvider: BaiduPanProvider
    private let iCloudProvider: ICloudProvider
    private let photosProvider: PhotosProvider
    private let forceStubDeviceLocalBackup: Bool

    public init(
        api: BackupAPI,
        baiduPanProvider: BaiduPanProvider? = nil,
        iCloudProvider: ICloudProvider? = nil,
        photosProvider: PhotosProvider? = nil,
        forceStubOAuth: Bool = false
    ) {
        self.api = api
        self.forceStubDeviceLocalBackup = forceStubOAuth
        self.baiduPanProvider = baiduPanProvider ?? BaiduPanProviderFactory.make(forceStub: forceStubOAuth)
        self.iCloudProvider = iCloudProvider ?? ICloudProviderFactory.make(forceStub: forceStubOAuth)
        self.photosProvider = photosProvider ?? PhotosProviderFactory.make(forceStub: forceStubOAuth)
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
        let request = try await bindRequest(for: kind)
        return try await api.bindProvider(request)
    }

    public func unbindTarget(_ kind: BackupKind) async throws {
        switch kind {
        case .baiduPan:
            try await baiduPanProvider.revoke()
        case .photos:
            try await photosProvider.revoke()
        case .iCloud:
            break
        }

        let targets = try await listTargets()
        guard let provider = targets.first(where: { $0.kind == kind })?.provider else {
            return
        }
        _ = try await api.unbindProvider(id: provider.id)
    }

    public func backupStatus() async throws -> BackupStatusData {
        try await api.getStatus()
    }

    private func bindRequest(for kind: BackupKind) async throws -> BindBackupProviderRequest {
        switch kind {
        case .baiduPan:
            try await baiduPanProvider.authorize()
            guard let credentials = baiduPanProvider.currentCredentials() else {
                throw BaiduPanProviderError.notAuthorized
            }
            return Self.baiduBindRequest(credentials: credentials)
        case .iCloud:
            try await iCloudProvider.authorize()
            return Self.deviceLocalBindRequest(
                for: kind,
                mode: ICloudProviderFactory.currentMode(forceStub: forceStubDeviceLocalBackup)
            )
        case .photos:
            try await photosProvider.authorize()
            return Self.deviceLocalBindRequest(
                for: kind,
                mode: PhotosProviderFactory.currentMode(forceStub: forceStubDeviceLocalBackup)
            )
        }
    }

    private static func deviceLocalBindRequest(
        for kind: BackupKind,
        mode: DeviceLocalBackupMode
    ) -> BindBackupProviderRequest {
        BindBackupProviderRequest(
            kind: kind.apiKindValue,
            accessToken: "device-local",
            metadata: [
                "platform": "ios",
                "binding": "settings",
                "provider_mode": mode.rawValue,
            ]
        )
    }

    private static func baiduBindRequest(credentials: BaiduPanCredentials) -> BindBackupProviderRequest {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expiresAt = credentials.expiresAt.map { formatter.string(from: $0) }

        return BindBackupProviderRequest(
            kind: BackupKind.baiduPan.apiKindValue,
            accessToken: credentials.accessToken,
            refreshToken: credentials.refreshToken,
            expiresAt: expiresAt,
            providerAccountId: credentials.providerAccountId,
            metadata: [
                "platform": "ios",
                "binding": "settings",
                "oauth": "baidu_pan",
            ]
        )
    }
}
