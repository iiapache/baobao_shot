import DesignSystem
import Foundation

public enum DataExportUIState: Equatable, Sendable {
    case idle
    case exporting(DataExportProgress)
    case completed(URL)
    case failed(String)
}

@MainActor
public final class DataExportViewModel: ObservableObject {
    @Published public private(set) var state: DataExportUIState = .idle
    @Published public private(set) var isShareSheetPresented = false

    private let coordinator: DataExportBackgroundCoordinator
    private let familyId: String
    private var exportTask: Task<Void, Never>?

    public init(coordinator: DataExportBackgroundCoordinator, familyId: String) {
        self.coordinator = coordinator
        self.familyId = familyId
        coordinator.registerBackgroundHandlerIfNeeded()
    }

    public var canStartExport: Bool {
        switch state {
        case .idle, .failed, .completed:
            return true
        case .exporting:
            return false
        }
    }

    public var progress: DataExportProgress? {
        if case .exporting(let progress) = state {
            return progress
        }
        return nil
    }

    public var exportedArchiveURL: URL? {
        if case .completed(let url) = state {
            return url
        }
        return nil
    }

    public func startExport() {
        guard canStartExport else { return }
        state = .exporting(DataExportProgress(phase: .preparing, completedItems: 0, totalItems: 0))

        exportTask = Task { [weak self] in
            guard let self else { return }
            do {
                let archiveURL = try await coordinator.startExport(familyId: familyId) { progress in
                    Task { @MainActor in
                        self.state = .exporting(progress)
                    }
                }
                self.state = .completed(archiveURL)
                self.isShareSheetPresented = true
            } catch is CancellationError {
                self.state = .idle
            } catch let error as DataExportError {
                self.state = .failed(Self.message(for: error))
            } catch {
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    public func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        coordinator.cancelExport()
        state = .idle
    }

    public func dismissShareSheet() {
        isShareSheetPresented = false
    }

    public func reset() {
        exportTask?.cancel()
        exportTask = nil
        state = .idle
        isShareSheetPresented = false
    }

    private static func message(for error: DataExportError) -> String {
        switch error {
        case .familyNotFound:
            return L10n.string("settings.export.error.no_baby")
        case .noPhotosToExport:
            return L10n.string("settings.export.error.no_photos")
        case .missingPhotoFile(let photoId):
            return L10n.string("settings.export.error.missing_file", photoId)
        case .zipCreationFailed:
            return L10n.string("settings.export.error.zip_failed")
        case .encodingFailed:
            return L10n.string("settings.export.error.metadata_failed")
        case .cancelled:
            return L10n.string("settings.export.error.cancelled")
        }
    }
}
