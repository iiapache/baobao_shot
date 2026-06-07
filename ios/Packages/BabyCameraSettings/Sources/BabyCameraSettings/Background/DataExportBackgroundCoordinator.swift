import Foundation

public struct DataExportJob: Codable, Sendable, Equatable {
    public let familyId: String
    public let startedAt: Date

    public init(familyId: String, startedAt: Date = Date()) {
        self.familyId = familyId
        self.startedAt = startedAt
    }
}

public protocol DataExportJobPersisting: Sendable {
    func load() -> DataExportJob?
    func save(_ job: DataExportJob)
    func clear()
}

public struct UserDefaultsDataExportJobStore: DataExportJobPersisting {
    private let defaults: UserDefaults
    private let key = "settings.dataExport.activeJob"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> DataExportJob? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DataExportJob.self, from: data)
    }

    public func save(_ job: DataExportJob) {
        guard let data = try? JSONEncoder().encode(job) else { return }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}

/// 导出期间注册后台处理任务，并在 App 被挂起后继续执行。
public final class DataExportBackgroundCoordinator: @unchecked Sendable {
    private let exportService: any DataExportServing
    private let scheduler: any DataExportBackgroundScheduling
    private let jobStore: any DataExportJobPersisting
    private let taskIdentifier: String
    private var isCancelled = false
    private var isBackgroundHandlerRegistered = false
    private let lock = NSLock()

    public init(
        exportService: any DataExportServing,
        scheduler: any DataExportBackgroundScheduling,
        jobStore: any DataExportJobPersisting = UserDefaultsDataExportJobStore(),
        taskIdentifier: String = DataExportConfiguration.backgroundTaskIdentifier
    ) {
        self.exportService = exportService
        self.scheduler = scheduler
        self.jobStore = jobStore
        self.taskIdentifier = taskIdentifier
    }

    public func registerBackgroundHandlerIfNeeded() {
        lock.lock()
        let shouldRegister = !isBackgroundHandlerRegistered
        if shouldRegister {
            isBackgroundHandlerRegistered = true
        }
        lock.unlock()

        guard shouldRegister else { return }

        scheduler.register(identifier: taskIdentifier) { [weak self] in
            guard let self else { return false }
            return await self.resumePendingExportIfNeeded()
        }
    }

    @discardableResult
    public func startExport(
        familyId: String,
        progressHandler: @escaping @Sendable (DataExportProgress) -> Void
    ) async throws -> URL {
        lock.lock()
        isCancelled = false
        lock.unlock()

        jobStore.save(DataExportJob(familyId: familyId))
        await scheduleBackgroundTask()

        do {
            let archiveURL = try await exportService.export(
                familyId: familyId,
                progressHandler: progressHandler
            )
            if isCancelledFlag() {
                throw DataExportError.cancelled
            }
            jobStore.clear()
            return archiveURL
        } catch {
            if !isCancelledFlag() {
                jobStore.clear()
            }
            throw error
        }
    }

    public func cancelExport() {
        lock.lock()
        isCancelled = true
        lock.unlock()
        jobStore.clear()
    }

    @discardableResult
    public func resumePendingExportIfNeeded() async -> Bool {
        guard let job = jobStore.load() else { return true }
        do {
            _ = try await exportService.export(familyId: job.familyId) { _ in }
            jobStore.clear()
            return true
        } catch {
            return false
        }
    }

    private func scheduleBackgroundTask() async {
        _ = await scheduler.submit(
            DataExportBackgroundRequest(identifier: taskIdentifier)
        )
    }

    private func isCancelledFlag() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelled
    }
}
