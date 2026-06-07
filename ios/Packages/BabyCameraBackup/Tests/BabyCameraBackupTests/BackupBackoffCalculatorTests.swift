import XCTest
@testable import BabyCameraBackup

final class BackupBackoffCalculatorTests: XCTestCase {
    func testExponentialBackoffSequenceCapsAtMaxDelay() {
        let configuration = BackupQueueConfiguration(
            retryBaseDelaySeconds: 1,
            retryMaxDelaySeconds: 8
        )

        XCTAssertEqual(
            BackupBackoffCalculator.delaySeconds(forFailedAttempt: 1, configuration: configuration),
            1
        )
        XCTAssertEqual(
            BackupBackoffCalculator.delaySeconds(forFailedAttempt: 2, configuration: configuration),
            2
        )
        XCTAssertEqual(
            BackupBackoffCalculator.delaySeconds(forFailedAttempt: 3, configuration: configuration),
            4
        )
        XCTAssertEqual(
            BackupBackoffCalculator.delaySeconds(forFailedAttempt: 4, configuration: configuration),
            8
        )
        XCTAssertEqual(
            BackupBackoffCalculator.delaySeconds(forFailedAttempt: 5, configuration: configuration),
            8
        )
    }

    func testZeroAttemptReturnsZeroDelay() {
        XCTAssertEqual(
            BackupBackoffCalculator.delaySeconds(forFailedAttempt: 0),
            0
        )
    }
}
