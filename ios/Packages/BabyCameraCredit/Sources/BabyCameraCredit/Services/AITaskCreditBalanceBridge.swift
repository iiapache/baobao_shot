import BabyCameraNetwork
import Foundation

/// 将 AI WebSocket 任务事件中的 `balanceAfter` 转为积分余额更新流。
public enum AITaskCreditBalanceBridge {
    public static func balanceEvents(from taskEvents: AsyncStream<AITaskEvent>) -> AsyncStream<AITaskBalanceEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await event in taskEvents {
                    guard !Task.isCancelled else { break }
                    guard let balanceAfter = event.balanceAfter, !event.taskId.isEmpty else { continue }
                    continuation.yield(
                        AITaskBalanceEvent(taskId: event.taskId, balanceAfter: balanceAfter)
                    )
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
