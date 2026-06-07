import Foundation
import UniformTypeIdentifiers

#if canImport(PhotosUI)
import PhotosUI
#endif

/// 从 PHPicker 选中项加载图片二进制。
public protocol PickerItemLoading: Sendable {
    func loadImageData(from item: PickerImportItem) async throws -> Data
}

#if canImport(PhotosUI)

/// 基于 `PHPickerResult.itemProvider` 的加载实现。
public final class PHPickerItemLoader: PickerItemLoading, @unchecked Sendable {
    private let itemProvidersByID: [String: NSItemProvider]

    public init(results: [PHPickerResult]) {
        var map: [String: NSItemProvider] = [:]
        for (index, result) in results.enumerated() {
            let id = result.assetIdentifier ?? "picker-\(index)"
            map[id] = result.itemProvider
        }
        self.itemProvidersByID = map
    }

    public func loadImageData(from item: PickerImportItem) async throws -> Data {
        guard let provider = itemProvidersByID[item.id] else {
            throw ImportError.loadFailed("unknown picker item: \(item.id)")
        }

        let typeIdentifiers = [
            UTType.image.identifier,
            UTType.jpeg.identifier,
            UTType.heic.identifier,
            UTType.png.identifier,
        ]

        for typeIdentifier in typeIdentifiers {
            if provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                return try await loadData(from: provider, typeIdentifier: typeIdentifier)
            }
        }

        throw ImportError.loadFailed("no supported image type for item: \(item.id)")
    }

    private func loadData(from provider: NSItemProvider, typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: ImportError.loadFailed(error.localizedDescription))
                    return
                }
                guard let data, !data.isEmpty else {
                    continuation.resume(throwing: ImportError.loadFailed("empty image data"))
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }
}

extension PickerImportItem {
    /// 从 PHPicker 结果构造可导入项；无 `assetIdentifier` 时使用序号占位 ID。
    public static func from(results: [PHPickerResult]) -> [PickerImportItem] {
        results.enumerated().map { index, result in
            PickerImportItem(id: result.assetIdentifier ?? "picker-\(index)")
        }
    }
}

#endif
