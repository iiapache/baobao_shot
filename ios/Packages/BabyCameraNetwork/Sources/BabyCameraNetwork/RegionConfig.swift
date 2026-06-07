import Foundation

public enum AppRegion: String, Sendable, Codable {
    case cn
    case os

    public var baseURL: URL {
        switch self {
        case .cn:
            return URL(string: "https://api-cn.babygrowth.app")!
        case .os:
            return URL(string: "https://api-os.babygrowth.app")!
        }
    }

    public var webSocketBaseURL: URL {
        switch self {
        case .cn:
            return URL(string: "wss://ws-cn.babygrowth.app")!
        case .os:
            return URL(string: "wss://ws-os.babygrowth.app")!
        }
    }

    public var headerValue: String { rawValue }
}

public struct RegionConfig: Sendable {
    public let region: AppRegion
    public let appVersion: String
    public let deviceId: String

    public init(region: AppRegion, appVersion: String, deviceId: String) {
        self.region = region
        self.appVersion = appVersion
        self.deviceId = deviceId
    }
}
