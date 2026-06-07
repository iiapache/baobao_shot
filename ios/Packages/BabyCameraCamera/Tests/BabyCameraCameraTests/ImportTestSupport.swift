import Foundation
@testable import BabyCameraCamera

/// 单测用 Picker 加载器，按 item ID 返回预设图片数据。
struct MockPickerItemLoader: PickerItemLoading {
    private let dataByItemID: [String: Data]

    init(dataByItemID: [String: Data]) {
        self.dataByItemID = dataByItemID
    }

    func loadImageData(from item: PickerImportItem) async throws -> Data {
        guard let data = dataByItemID[item.id] else {
            throw ImportError.loadFailed("missing mock data for \(item.id)")
        }
        return data
    }
}
