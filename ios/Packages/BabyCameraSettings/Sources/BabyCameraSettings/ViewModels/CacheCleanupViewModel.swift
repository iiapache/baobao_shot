import Foundation

public enum CacheCleanupUIState: Equatable, Sendable {
    case loading
    case ready(CacheCleanupMetrics)
    case cleared
    case failed(String)
}

@MainActor
public final class CacheCleanupViewModel: ObservableObject {
    @Published public private(set) var state: CacheCleanupUIState = .loading
    @Published public var showsClearConfirmation = false

    private let service: CacheCleanupService

    public init(service: CacheCleanupService) {
        self.service = service
    }

    public func refresh() async {
        state = .loading
        let metrics = await service.currentMetrics()
        state = .ready(metrics)
    }

    public func requestClear() {
        showsClearConfirmation = true
    }

    public func confirmClear() async {
        showsClearConfirmation = false
        do {
            try await service.clearAllCaches()
            let metrics = await service.currentMetrics()
            if metrics.totalSizeBytes == 0, metrics.thumbnailMetrics.totalRequests == 0 {
                state = .cleared
            } else {
                state = .ready(metrics)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    public static func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    public static func formattedHitRate(_ rate: Double) -> String {
        guard rate > 0 else { return "0%" }
        return String(format: "%.1f%%", rate * 100)
    }
}
