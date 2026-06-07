import Foundation

/// 评估 Wi-Fi + 充电 + 电量 > 30% 自动备份触发条件（design-ios §12.2）。
public enum BackupTriggerEvaluator {
    public static func evaluateAutomaticTrigger(
        preferences: BackupAutoBackupPreferences,
        device: BackupDeviceSnapshot
    ) -> BackupTriggerEvaluation {
        var blockReasons: [BackupTriggerBlockReason] = []

        if !preferences.isAutomaticBackupEnabled {
            blockReasons.append(.autoBackupDisabled)
        }
        if !device.isOnWiFi {
            blockReasons.append(.notOnWiFi)
        }
        if !device.isCharging {
            blockReasons.append(.notCharging)
        }
        if device.batteryLevel <= preferences.minimumBatteryLevel {
            blockReasons.append(
                .batteryTooLow(
                    current: device.batteryLevel,
                    required: preferences.minimumBatteryLevel
                )
            )
        }

        return BackupTriggerEvaluation(
            canRun: blockReasons.isEmpty,
            blockReasons: blockReasons
        )
    }
}
