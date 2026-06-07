import Foundation

/// App 版本信息，供「关于」页展示。
public struct AppVersionInfo: Equatable, Sendable {
    public let marketingVersion: String
    public let buildNumber: String

    public init(marketingVersion: String, buildNumber: String) {
        self.marketingVersion = marketingVersion
        self.buildNumber = buildNumber
    }

    public var displayString: String {
        if buildNumber.isEmpty {
            return marketingVersion
        }
        return "\(marketingVersion) (\(buildNumber))"
    }

    public static let placeholder = AppVersionInfo(marketingVersion: "1.0.0", buildNumber: "1")

    public static func fromBundle(_ bundle: Bundle = .main) -> AppVersionInfo {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return AppVersionInfo(marketingVersion: version, buildNumber: build)
    }
}
