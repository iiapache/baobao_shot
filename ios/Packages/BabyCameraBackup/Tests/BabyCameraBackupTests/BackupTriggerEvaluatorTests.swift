import XCTest
@testable import BabyCameraBackup

final class BackupTriggerEvaluatorTests: XCTestCase {
    private let preferences = BackupAutoBackupPreferences()

    func testEligibleWhenWiFiChargingAndBatteryAboveThreshold() {
        let evaluation = BackupTriggerEvaluator.evaluateAutomaticTrigger(
            preferences: preferences,
            device: makeEligibleDevice(batteryLevel: 0.31)
        )

        XCTAssertTrue(evaluation.canRun)
        XCTAssertTrue(evaluation.blockReasons.isEmpty)
    }

    func testBlockedWhenNotOnWiFi() {
        let evaluation = BackupTriggerEvaluator.evaluateAutomaticTrigger(
            preferences: preferences,
            device: makeEligibleDevice(isOnWiFi: false)
        )

        XCTAssertFalse(evaluation.canRun)
        XCTAssertTrue(evaluation.blockReasons.contains(.notOnWiFi))
    }

    func testBlockedWhenNotCharging() {
        let evaluation = BackupTriggerEvaluator.evaluateAutomaticTrigger(
            preferences: preferences,
            device: makeEligibleDevice(isCharging: false)
        )

        XCTAssertFalse(evaluation.canRun)
        XCTAssertTrue(evaluation.blockReasons.contains(.notCharging))
    }

    func testBlockedWhenBatteryAtOrBelow30Percent() {
        let atThreshold = BackupTriggerEvaluator.evaluateAutomaticTrigger(
            preferences: preferences,
            device: makeEligibleDevice(batteryLevel: 0.30)
        )
        let belowThreshold = BackupTriggerEvaluator.evaluateAutomaticTrigger(
            preferences: preferences,
            device: makeEligibleDevice(batteryLevel: 0.29)
        )

        XCTAssertFalse(atThreshold.canRun)
        XCTAssertFalse(belowThreshold.canRun)
        XCTAssertEqual(
            atThreshold.blockReasons,
            [.batteryTooLow(current: 0.30, required: 0.30)]
        )
        XCTAssertEqual(
            belowThreshold.blockReasons,
            [.batteryTooLow(current: 0.29, required: 0.30)]
        )
    }

    func testBlockedWhenAutoBackupDisabled() {
        var preferences = BackupAutoBackupPreferences()
        preferences.isAutomaticBackupEnabled = false

        let evaluation = BackupTriggerEvaluator.evaluateAutomaticTrigger(
            preferences: preferences,
            device: makeEligibleDevice()
        )

        XCTAssertFalse(evaluation.canRun)
        XCTAssertTrue(evaluation.blockReasons.contains(.autoBackupDisabled))
    }

    func testCollectsMultipleBlockReasons() {
        let evaluation = BackupTriggerEvaluator.evaluateAutomaticTrigger(
            preferences: preferences,
            device: BackupDeviceSnapshot(
                isOnWiFi: false,
                isCharging: false,
                batteryLevel: 0.10
            )
        )

        XCTAssertFalse(evaluation.canRun)
        XCTAssertEqual(evaluation.blockReasons.count, 3)
        XCTAssertTrue(evaluation.blockReasons.contains(.notOnWiFi))
        XCTAssertTrue(evaluation.blockReasons.contains(.notCharging))
        XCTAssertTrue(evaluation.blockReasons.contains(.batteryTooLow(current: 0.10, required: 0.30)))
    }
}
