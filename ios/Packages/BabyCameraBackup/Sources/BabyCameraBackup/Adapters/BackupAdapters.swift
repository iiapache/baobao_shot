import Foundation

public actor InMemoryBackupDedupStore: BackupDedupStore {
    private var hashesByProvider: [BackupKind: Set<String>]

    public init(initial: [BackupKind: Set<String>] = [:]) {
        self.hashesByProvider = initial
    }

    public func backedUpHashes(for provider: BackupKind) async throws -> Set<String> {
        hashesByProvider[provider] ?? []
    }

    public func markBackedUp(sha256: String, provider: BackupKind) async throws {
        var hashes = hashesByProvider[provider] ?? []
        hashes.insert(sha256)
        hashesByProvider[provider] = hashes
    }
}

#if canImport(UIKit)
import UIKit

public struct LiveBackupDeviceConditionMonitor: BackupDeviceConditionMonitoring {
    public init() {}

    public func currentSnapshot() async -> BackupDeviceSnapshot {
        await MainActor.run {
            let device = UIDevice.current
            device.isBatteryMonitoringEnabled = true

            let batteryLevel = device.batteryLevel >= 0 ? Double(device.batteryLevel) : 1.0
            let isCharging: Bool = {
                switch device.batteryState {
                case .charging, .full:
                    return true
                case .unplugged, .unknown:
                    return false
                @unknown default:
                    return false
                }
            }()

            return BackupDeviceSnapshot(
                isOnWiFi: Self.isOnWiFi(),
                isCharging: isCharging,
                batteryLevel: batteryLevel
            )
        }
    }

    private static func isOnWiFi() -> Bool {
        // NWPathMonitor 在 T6.2 队列层接入；此处保守返回 true 供 Live 占位。
        true
    }
}
#endif
