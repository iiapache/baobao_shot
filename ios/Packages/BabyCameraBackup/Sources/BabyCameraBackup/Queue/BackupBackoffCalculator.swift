import Foundation

public enum BackupBackoffCalculator {
    /// 按 1s, 2s, 4s … 计算退避，上限 `retryMaxDelaySeconds`。
    /// - Parameter attempt: 1-based 失败次数。
    public static func delaySeconds(
        forFailedAttempt attempt: Int,
        configuration: BackupQueueConfiguration = .default
    ) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let exponent = Double(attempt - 1)
        let delay = configuration.retryBaseDelaySeconds * pow(2.0, exponent)
        return min(delay, configuration.retryMaxDelaySeconds)
    }
}
