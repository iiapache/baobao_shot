import Foundation

public struct BackupAutoBackupPreferences: Sendable, Equatable, Codable {
    /// 用户是否开启 Wi-Fi + 充电 + 电量条件自动备份。
    public var isAutomaticBackupEnabled: Bool
    public var minimumBatteryLevel: Double

    public init(
        isAutomaticBackupEnabled: Bool = true,
        minimumBatteryLevel: Double = 0.30
    ) {
        self.isAutomaticBackupEnabled = isAutomaticBackupEnabled
        self.minimumBatteryLevel = minimumBatteryLevel
    }
}

public struct BackupDeviceSnapshot: Sendable, Equatable {
    public let isOnWiFi: Bool
    public let isCharging: Bool
    /// 0.0 ... 1.0
    public let batteryLevel: Double

    public init(isOnWiFi: Bool, isCharging: Bool, batteryLevel: Double) {
        self.isOnWiFi = isOnWiFi
        self.isCharging = isCharging
        self.batteryLevel = batteryLevel
    }
}

public enum BackupTriggerBlockReason: Sendable, Equatable {
    case autoBackupDisabled
    case notOnWiFi
    case notCharging
    case batteryTooLow(current: Double, required: Double)
}

public struct BackupTriggerEvaluation: Sendable, Equatable {
    public let canRun: Bool
    public let blockReasons: [BackupTriggerBlockReason]

    public init(canRun: Bool, blockReasons: [BackupTriggerBlockReason] = []) {
        self.canRun = canRun
        self.blockReasons = blockReasons
    }
}

public enum BackupRunTrigger: String, Sendable, Equatable, Codable {
    case manual
    case automatic
}

public struct BackupProviderRunResult: Sendable, Equatable {
    public let kind: BackupKind
    public let uploadedCount: Int
    public let skippedCount: Int
    public let uploadedSHA256s: [String]

    public init(
        kind: BackupKind,
        uploadedCount: Int,
        skippedCount: Int,
        uploadedSHA256s: [String]
    ) {
        self.kind = kind
        self.uploadedCount = uploadedCount
        self.skippedCount = skippedCount
        self.uploadedSHA256s = uploadedSHA256s
    }
}

public struct BackupRunReport: Sendable, Equatable {
    public let trigger: BackupRunTrigger
    public let providerResults: [BackupProviderRunResult]

    public init(trigger: BackupRunTrigger, providerResults: [BackupProviderRunResult]) {
        self.trigger = trigger
        self.providerResults = providerResults
    }

    public var totalUploadedCount: Int {
        providerResults.reduce(0) { $0 + $1.uploadedCount }
    }
}

public enum BackupOrchestratorError: Error, Sendable, Equatable {
    case triggerConditionsNotMet([BackupTriggerBlockReason])
    case noProvidersConfigured
}

public protocol BackupDeviceConditionMonitoring: Sendable {
    func currentSnapshot() async -> BackupDeviceSnapshot
}

public protocol BackupPhotoSource: Sendable {
    func pendingPhotos() async throws -> [BackupPhotoCandidate]
}

public protocol BackupDedupStore: Sendable {
    func backedUpHashes(for provider: BackupKind) async throws -> Set<String>
    func markBackedUp(sha256: String, provider: BackupKind) async throws
}

public protocol BackupClock: Sendable {
    func nowUnixMillis() -> Int64
}

public struct SystemBackupClock: BackupClock {
    public init() {}

    public func nowUnixMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
