import Foundation

public struct BackupOrchestrator: Sendable {
    private let photoSource: any BackupPhotoSource
    private let dedupStore: any BackupDedupStore
    private let deviceMonitor: any BackupDeviceConditionMonitoring

    public init(
        photoSource: any BackupPhotoSource,
        dedupStore: any BackupDedupStore,
        deviceMonitor: any BackupDeviceConditionMonitoring
    ) {
        self.photoSource = photoSource
        self.dedupStore = dedupStore
        self.deviceMonitor = deviceMonitor
    }

    public func evaluateAutomaticTrigger(
        preferences: BackupAutoBackupPreferences
    ) async -> BackupTriggerEvaluation {
        let device = await deviceMonitor.currentSnapshot()
        return BackupTriggerEvaluator.evaluateAutomaticTrigger(
            preferences: preferences,
            device: device
        )
    }

    public func runBackup(
        trigger: BackupRunTrigger,
        providers: [any BackupProvider],
        preferences: BackupAutoBackupPreferences
    ) async throws -> BackupRunReport {
        guard !providers.isEmpty else {
            throw BackupOrchestratorError.noProvidersConfigured
        }

        if case .automatic = trigger {
            let evaluation = await evaluateAutomaticTrigger(preferences: preferences)
            guard evaluation.canRun else {
                throw BackupOrchestratorError.triggerConditionsNotMet(evaluation.blockReasons)
            }
        }

        let candidates = try await photoSource.pendingPhotos()
        var providerResults: [BackupProviderRunResult] = []
        providerResults.reserveCapacity(providers.count)

        for provider in providers {
            let result = try await runBackup(
                provider: provider,
                candidates: candidates
            )
            providerResults.append(result)
        }

        return BackupRunReport(trigger: trigger, providerResults: providerResults)
    }

    private func runBackup(
        provider: any BackupProvider,
        candidates: [BackupPhotoCandidate]
    ) async throws -> BackupProviderRunResult {
        try await provider.authorize()

        let backedUpHashes = try await dedupStore.backedUpHashes(for: provider.kind)
        let pending = BackupIncrementalFilter.pendingCandidates(candidates, backedUpHashes: backedUpHashes)

        var uploadedSHA256s: [String] = []
        uploadedSHA256s.reserveCapacity(pending.count)
        let skippedCount = candidates.count - pending.count

        for candidate in pending {
            let receipt = try await provider.upload(candidate.asBackupItem())
            try await dedupStore.markBackedUp(sha256: receipt.sha256, provider: provider.kind)
            uploadedSHA256s.append(receipt.sha256)
        }

        return BackupProviderRunResult(
            kind: provider.kind,
            uploadedCount: uploadedSHA256s.count,
            skippedCount: skippedCount,
            uploadedSHA256s: uploadedSHA256s
        )
    }
}
