import Foundation

/// Observes `AITaskCoordinator` updates and downloads succeeded tasks into local store.
public actor AITaskResultDownloadCoordinator {
    private let downloader: any AITaskResultDownloading
    private var contexts: [String: AITaskDownloadContext] = [:]
    private var inFlight: Set<String> = []
    private var observationTask: Task<Void, Never>?

    public init(downloader: any AITaskResultDownloading) {
        self.downloader = downloader
    }

    deinit {
        observationTask?.cancel()
    }

    public func register(taskId: String, context: AITaskDownloadContext) {
        contexts[taskId] = context
    }

    public func unregister(taskId: String) {
        contexts.removeValue(forKey: taskId)
        inFlight.remove(taskId)
    }

    public func startObserving(_ coordinator: AITaskCoordinator) {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in await coordinator.updates {
                await self.handle(snapshot: snapshot, coordinator: coordinator)
            }
        }
    }

    public func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }

    private func handle(snapshot: AITaskSnapshot, coordinator: AITaskCoordinator) async {
        guard snapshot.phase == .succeeded,
              let resultUrl = snapshot.resultUrl,
              let context = contexts[snapshot.taskId],
              !inFlight.contains(snapshot.taskId) else {
            return
        }

        inFlight.insert(snapshot.taskId)
        defer { inFlight.remove(snapshot.taskId) }

        let request = AITaskDownloadRequest(
            taskId: snapshot.taskId,
            resultUrl: resultUrl,
            context: context
        )

        do {
            _ = try await downloader.download(request)
            await coordinator.markDownloaded(taskId: snapshot.taskId)
            contexts.removeValue(forKey: snapshot.taskId)
        } catch {
            // Leave task in succeeded phase so caller can retry manually.
        }
    }
}
