import Foundation

public protocol BabyWidgetSnapshotLoading: Sendable {
    func loadSnapshot() throws -> WidgetSnapshot?
}

public struct BabyWidgetSnapshotLoader: BabyWidgetSnapshotLoading {
    private let store: any WidgetSnapshotStoring

    public init(store: any WidgetSnapshotStoring = WidgetAppGroupStore()) {
        self.store = store
    }

    public func loadSnapshot() throws -> WidgetSnapshot? {
        try store.readSnapshot()
    }
}
