import Foundation

/// 仓库 `compliance/client-config.yaml` 同步的内置合规配置（离线 / 远端占位 fallback）。
enum ComplianceBundledConfig {
    private struct Payload: Decodable {
        let version: String
        let status: String
        let icpNumber: String
        let icpQueryURL: String
        let algorithmFilingSummary: String

        enum CodingKeys: String, CodingKey {
            case version
            case status
            case icpNumber = "icp_number"
            case icpQueryURL = "icp_query_url"
            case algorithmFilingSummary = "algorithm_filing_summary"
        }
    }

    static func load() -> ComplianceConfig? {
        guard let url = Bundle.module.url(
            forResource: "ComplianceBundledConfig",
            withExtension: "json"
        ) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        return ComplianceConfig(
            icpNumber: payload.icpNumber,
            icpQueryURL: URL(string: payload.icpQueryURL),
            algorithmFilingSummary: payload.algorithmFilingSummary
        )
    }
}
