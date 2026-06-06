import Foundation

/// 撤销 / 重做快照栈：`steps` 数组的不可变快照。
struct EditorSnapshotStack: Equatable, Sendable {
    private var undoSnapshots: [[AnyEditStep]] = []
    private var redoSnapshots: [[AnyEditStep]] = []
    private let maxUndoLevels: Int?

    var canUndo: Bool { !undoSnapshots.isEmpty }
    var canRedo: Bool { !redoSnapshots.isEmpty }
    var undoCount: Int { undoSnapshots.count }
    var redoCount: Int { redoSnapshots.count }

    init(maxUndoLevels: Int? = nil) {
        self.maxUndoLevels = maxUndoLevels
    }

    /// 在变更前保存当前 `steps`；新编辑会清空 redo 栈。
    mutating func pushUndoSnapshot(_ steps: [AnyEditStep]) {
        undoSnapshots.append(steps)
        redoSnapshots.removeAll(keepingCapacity: false)
        trimUndoStackIfNeeded()
    }

    /// 撤销：弹出 undo 栈顶，将当前状态压入 redo。
    mutating func undo(currentSteps: [AnyEditStep]) -> [AnyEditStep]? {
        guard let previous = undoSnapshots.popLast() else { return nil }
        redoSnapshots.append(currentSteps)
        return previous
    }

    /// 重做：弹出 redo 栈顶，将当前状态压入 undo。
    mutating func redo(currentSteps: [AnyEditStep]) -> [AnyEditStep]? {
        guard let next = redoSnapshots.popLast() else { return nil }
        undoSnapshots.append(currentSteps)
        return next
    }

    mutating func clear() {
        undoSnapshots.removeAll(keepingCapacity: false)
        redoSnapshots.removeAll(keepingCapacity: false)
    }

    private mutating func trimUndoStackIfNeeded() {
        guard let maxUndoLevels, undoSnapshots.count > maxUndoLevels else { return }
        undoSnapshots.removeFirst(undoSnapshots.count - maxUndoLevels)
    }
}
