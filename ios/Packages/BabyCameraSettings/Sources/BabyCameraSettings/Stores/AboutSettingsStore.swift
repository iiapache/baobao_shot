import BabyCameraNetwork
import Foundation

@MainActor
public final class AboutSettingsStore: ObservableObject {
    @Published public private(set) var compliance = ComplianceConfig.defaults(for: .cn)
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?

    public let versionInfo: AppVersionInfo
    private let complianceService: any ComplianceConfigServing

    public init(
        complianceService: any ComplianceConfigServing,
        versionInfo: AppVersionInfo
    ) {
        self.complianceService = complianceService
        self.versionInfo = versionInfo
    }

    public var icpDisplayText: String {
        compliance.icpNumber ?? ComplianceConfig.icpPendingText
    }

    public var algorithmFilingDisplayText: String {
        compliance.algorithmFilingSummary ?? ComplianceConfig.algorithmPendingText
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            compliance = try await complianceService.fetchComplianceConfig()
        } catch {
            errorMessage = mapError(error)
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }
}
