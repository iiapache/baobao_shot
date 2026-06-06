import CoreImage
import Foundation

/// 编辑器画布状态：`steps` 为单一事实源，撤销/重做基于快照栈。
public final class EditorState: @unchecked Sendable {
    public private(set) var steps: [AnyEditStep]
    private var snapshotStack: EditorSnapshotStack

    public var canUndo: Bool { snapshotStack.canUndo }
    public var canRedo: Bool { snapshotStack.canRedo }
    public var stepCount: Int { steps.count }

    public init(steps: [AnyEditStep] = [], maxUndoLevels: Int? = nil) {
        self.steps = steps
        self.snapshotStack = EditorSnapshotStack(maxUndoLevels: maxUndoLevels)
    }

    /// 追加一步编辑；自动保存撤销快照并清空 redo。
    @discardableResult
    public func append(_ step: AnyEditStep) -> EditorState {
        snapshotStack.pushUndoSnapshot(steps)
        steps.append(step)
        return self
    }

    /// 追加具体步骤类型。
    @discardableResult
    public func append<S: EditStep>(_ step: S) -> EditorState {
        append(AnyEditStep(step))
    }

    /// 移除最后一步。
    @discardableResult
    public func removeLastStep() -> EditorState {
        guard !steps.isEmpty else { return self }
        snapshotStack.pushUndoSnapshot(steps)
        steps.removeLast()
        return self
    }

    /// 替换全部步骤（不记录撤销）。
    @discardableResult
    public func replaceSteps(_ newSteps: [AnyEditStep], clearHistory: Bool = true) -> EditorState {
        steps = newSteps
        if clearHistory {
            snapshotStack.clear()
        }
        return self
    }

    /// 撤销到上一快照。
    @discardableResult
    public func undo() -> EditorState {
        guard let previous = snapshotStack.undo(currentSteps: steps) else { return self }
        steps = previous
        return self
    }

    /// 重做：弹出 redo 栈顶，将当前状态压入 undo。
    @discardableResult
    public func redo() -> EditorState {
        guard let next = snapshotStack.redo(currentSteps: steps) else { return self }
        steps = next
        return self
    }

    /// 按顺序重放全部步骤，得到最终 CIImage。
    public func render(baseImage: CIImage) -> CIImage {
        steps.reduce(baseImage) { current, step in
            step.apply(to: current)
        }
    }

    /// 序列化为 JSON Data（供 `meta/edit_steps/` 持久化）。
    public func encodedSteps() throws -> Data {
        try JSONEncoder().encode(steps)
    }

    /// 从 JSON Data 恢复步骤（不记录撤销历史）。
    public static func decodeSteps(from data: Data) throws -> [AnyEditStep] {
        try JSONDecoder().decode([AnyEditStep].self, from: data)
    }
}

extension EditorState {
    /// 供单测断言快照栈深度。
    var undoSnapshotCount: Int { snapshotStack.undoCount }
    var redoSnapshotCount: Int { snapshotStack.redoCount }
}
