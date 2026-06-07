import BabyCameraImageKit
import Foundation
import UIKit

/// 通过 ImageKit 缩略图缓存加载 Timeline cell 图片。
@MainActor
public final class TimelineThumbnailLoader: ObservableObject {
    private let cache: any ThumbnailCaching
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    public init(cache: any ThumbnailCaching = DiskLRUThumbnailCache()) {
        self.cache = cache
    }

    public func loadImage(for filePath: String, size: ThumbnailSize = .small) async -> UIImage? {
        let taskKey = "\(filePath)-\(size.rawValue)"
        if let existing = inFlight[taskKey] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            do {
                let data = try await cache.loadThumbnail(filePath: filePath, size: size)
                return UIImage(data: data)
            } catch {
                return nil
            }
        }
        inFlight[taskKey] = task
        defer { inFlight[taskKey] = nil }
        return await task.value
    }

    public func cancelAll() {
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
    }
}
