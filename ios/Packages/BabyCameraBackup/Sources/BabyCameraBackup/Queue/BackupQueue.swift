import Foundation

/// 本地备份任务队列：持久化、指数退避重试、离线恢复、连续失败弹窗。
public actor BackupQueue {
    private let orchestrator: BackupOrchestrator
    private let persistence: any BackupQueuePersisting
    private let providerResolver: any BackupProviderResolving
    private let networkMonitor: any BackupNetworkMonitoring
    private let alertPresenter: any BackupConsecutiveFailureAlerting
    private let clock: any BackupClock
    private let sleeper: any BackupQueueSleeping
    private let configuration: BackupQueueConfiguration

    private var state: BackupQueuePersistedState?
    private var isProcessing = false
    private var isMonitoring = false
    private var isOnline = false

    public init(
        orchestrator: BackupOrchestrator,
        persistence: any BackupQueuePersisting,
        providerResolver: any BackupProviderResolving,
        networkMonitor: any BackupNetworkMonitoring,
        alertPresenter: any BackupConsecutiveFailureAlerting,
        clock: any BackupClock = SystemBackupClock(),
        sleeper: any BackupQueueSleeping = ImmediateBackupQueueSleeper(),
        configuration: BackupQueueConfiguration = .default
    ) {
        self.orchestrator = orchestrator
        self.persistence = persistence
        self.providerResolver = providerResolver
        self.networkMonitor = networkMonitor
        self.alertPresenter = alertPresenter
        self.clock = clock
        self.sleeper = sleeper
        self.configuration = configuration
    }

    public var pendingTaskCount: Int {
        get async throws {
            try await loadStateIfNeeded()
            return state?.tasks.count ?? 0
        }
    }

    public var consecutiveFailureCount: Int {
        get async throws {
            try await loadStateIfNeeded()
            return state?.consecutiveFailureCount ?? 0
        }
    }

    public func snapshot() async throws -> [BackupQueueTask] {
        try await loadStateIfNeeded()
        return state?.tasks ?? []
    }

    @discardableResult
    public func enqueue(
        trigger: BackupRunTrigger,
        providerKinds: [BackupKind],
        preferences: BackupAutoBackupPreferences = BackupAutoBackupPreferences()
    ) async throws -> BackupQueueTask {
        try await loadStateIfNeeded()
        let task = BackupQueueTask(
            trigger: trigger,
            providerKinds: providerKinds,
            preferences: preferences,
            enqueuedAt: clock.nowUnixMillis()
        )
        state?.tasks.append(task)
        try await persistState()
        await scheduleProcessingIfPossible()
        return task
    }

    public func start() async {
        guard !isMonitoring else { return }
        isMonitoring = true

        networkMonitor.start { [weak self] snapshot in
            guard let self else { return }
            Task {
                await self.handleNetworkChange(snapshot)
            }
        }

        let snapshot = await networkMonitor.currentSnapshot()
        await handleNetworkChange(snapshot)
    }

    public func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        networkMonitor.stop()
    }

    public func processNow() async {
        await processPendingTasks()
    }

    private func handleNetworkChange(_ snapshot: BackupNetworkSnapshot) async {
        let wasOffline = !isOnline
        isOnline = snapshot.isOnline
        if snapshot.isOnline && wasOffline {
            await processPendingTasks()
        }
    }

    private func scheduleProcessingIfPossible() async {
        guard isOnline else { return }
        await processPendingTasks()
    }

    private func processPendingTasks() async {
        guard !isProcessing else { return }
        guard isOnline else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await loadStateIfNeeded()
        } catch {
            return
        }

        while isOnline {
            guard let index = nextReadyTaskIndex() else { break }
            await executeTask(at: index)
        }
    }

    private func nextReadyTaskIndex() -> Int? {
        guard let tasks = state?.tasks else { return nil }
        let now = clock.nowUnixMillis()
        return tasks.firstIndex { task in
            guard let nextRetryAt = task.nextRetryAt else { return true }
            return nextRetryAt <= now
        }
    }

    private func executeTask(at index: Int) async {
        guard var tasks = state?.tasks, tasks.indices.contains(index) else { return }
        var task = tasks[index]
        let providers = providerResolver.providers(for: task.providerKinds)

        if providers.isEmpty {
            await recordTaskFailureRound(at: index, task: &task)
            return
        }

        while task.attemptCount < configuration.maxAttemptsPerTask {
            do {
                _ = try await orchestrator.runBackup(
                    trigger: task.trigger,
                    providers: providers,
                    preferences: task.preferences
                )
                await markTaskSucceeded(at: index)
                return
            } catch let error as BackupOrchestratorError {
                switch error {
                case .triggerConditionsNotMet:
                    await deferTaskForTriggerConditions(at: index, task: task)
                    return
                case .noProvidersConfigured:
                    await recordTaskFailureRound(at: index, task: &task)
                    return
                }
            } catch {
                task.attemptCount += 1
                let delay = BackupBackoffCalculator.delaySeconds(
                    forFailedAttempt: task.attemptCount,
                    configuration: configuration
                )
                state?.tasks[index] = task
                try? await persistState()
                await sleeper.sleep(seconds: delay)

                if task.attemptCount >= configuration.maxAttemptsPerTask {
                    await recordTaskFailureRound(at: index, task: &task)
                    return
                }
            }
        }
    }

    private func recordTaskFailureRound(at index: Int, task: inout BackupQueueTask) async {
        let delay = BackupBackoffCalculator.delaySeconds(
            forFailedAttempt: configuration.maxAttemptsPerTask,
            configuration: configuration
        )
        task.attemptCount = 0
        task.nextRetryAt = clock.nowUnixMillis() + Int64(delay * 1000)
        state?.tasks[index] = task
        state?.consecutiveFailureCount += 1

        let consecutive = state?.consecutiveFailureCount ?? 0
        if consecutive >= configuration.consecutiveFailureAlertThreshold {
            await alertPresenter.showConsecutiveFailureAlert(consecutiveFailures: consecutive)
        }

        try? await persistState()
    }

    private func markTaskSucceeded(at index: Int) async {
        guard var tasks = state?.tasks, tasks.indices.contains(index) else { return }
        tasks.remove(at: index)
        state?.tasks = tasks
        state?.consecutiveFailureCount = 0
        try? await persistState()
    }

    private func deferTaskForTriggerConditions(at index: Int, task: BackupQueueTask) async {
        var deferred = task
        deferred.nextRetryAt = clock.nowUnixMillis()
            + Int64(configuration.triggerDeferDelaySeconds * 1000)
        state?.tasks[index] = deferred
        try? await persistState()
    }

    private func loadStateIfNeeded() async throws {
        guard state == nil else { return }
        state = try await persistence.loadState()
    }

    private func persistState() async throws {
        guard let state else { return }
        try await persistence.saveState(state)
    }
}
