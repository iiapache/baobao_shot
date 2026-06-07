import BabyCameraNetwork
import Foundation

public struct ComplianceConfigService: ComplianceConfigServing {
    private let api: FeatureFlagsAPI
    private let region: AppRegion

    public init(client: APIClient, region: AppRegion) {
        self.api = FeatureFlagsAPI(client: client)
        self.region = region
    }

    public func fetchComplianceConfig() async throws -> ComplianceConfig {
        let payload = try await api.fetchFeatures()
        return ComplianceConfigResolver.resolve(features: payload.features, region: region)
    }
}
