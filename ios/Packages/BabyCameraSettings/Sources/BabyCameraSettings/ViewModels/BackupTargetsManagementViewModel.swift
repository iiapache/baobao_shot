import BabyCameraBackup
import BabyCameraNetwork
import DesignSystem
import Foundation

public struct BackupStatusSummary: Equatable, Sendable {
    public let lastSuccessAt: String?
    public let lastAttemptAt: String?
    public let failureCount: Int
    public let lastErrorCode: String?

    public init(status: BackupStatusData) {
        lastSuccessAt = status.lastSuccessAt
        lastAttemptAt = status.lastAttemptAt
        failureCount = status.failureCount
        lastErrorCode = status.lastErrorCode
    }

    public var statusLabel: String {
        if let lastSuccessAt, !lastSuccessAt.isEmpty {
            return L10n.string("settings.backup.status.success", Self.formatISO8601(lastSuccessAt))
        }
        if failureCount > 0 {
            if let code = lastErrorCode, !code.isEmpty {
                return L10n.string("settings.backup.status.failure_with_code", failureCount, code)
            }
            return L10n.string("settings.backup.status.failure", failureCount)
        }
        return L10n.string("settings.backup.status.never")
    }

    private static func formatISO8601(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return Self.displayFormatter.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return Self.displayFormatter.string(from: date)
        }
        return value
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

@MainActor
public final class BackupTargetsManagementViewModel: ObservableObject {
    @Published public private(set) var targets: [BackupTargetItem] = BackupKind.allCases.map {
        BackupTargetItem(kind: $0, provider: nil)
    }
    @Published public private(set) var statusSummary: BackupStatusSummary?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var updatingKinds: Set<BackupKind> = []

    private let service: any BackupTargetsServing

    public init(service: any BackupTargetsServing) {
        self.service = service
    }

    public func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            targets = try await service.listTargets()
            let status = try await service.backupStatus()
            statusSummary = BackupStatusSummary(status: status)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func setEnabled(_ kind: BackupKind, enabled: Bool) async {
        guard !updatingKinds.contains(kind) else { return }
        updatingKinds.insert(kind)
        errorMessage = nil
        defer { updatingKinds.remove(kind) }

        do {
            if enabled {
                _ = try await service.bindTarget(kind)
            } else {
                try await service.unbindTarget(kind)
            }
            targets = try await service.listTargets()
            let status = try await service.backupStatus()
            statusSummary = BackupStatusSummary(status: status)
        } catch {
            errorMessage = error.localizedDescription
            targets = (try? await service.listTargets()) ?? targets
        }
    }

    public func isUpdating(_ kind: BackupKind) -> Bool {
        updatingKinds.contains(kind)
    }

    public static func title(for kind: BackupKind) -> String {
        switch kind {
        case .iCloud: return "iCloud"
        case .photos: return L10n.string("settings.backup.photos")
        case .baiduPan: return L10n.string("settings.backup.baidu_pan")
        }
    }

    public static func subtitle(for item: BackupTargetItem) -> String {
        if item.isBound {
            return L10n.string("settings.backup.bound")
        }
        return L10n.string("settings.backup.unbound")
    }

    public static func icon(for kind: BackupKind) -> String {
        switch kind {
        case .iCloud: return "icloud.fill"
        case .photos: return "photo.on.rectangle.angled"
        case .baiduPan: return "externaldrive.fill"
        }
    }
}
