import Foundation

public protocol ComplianceConfigServing: Sendable {
    func fetchComplianceConfig() async throws -> ComplianceConfig
}
