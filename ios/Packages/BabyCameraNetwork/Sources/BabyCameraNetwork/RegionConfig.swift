import Foundation

/// 区域与客户端元数据。REST / WebSocket 基址由 `APIEnvironmentConfiguration` 从 Info.plist 读取（xcconfig 按 Build Configuration 注入）。
public enum AppRegion: String, Sendable, Codable {
    case cn
    case os

    /// 生产环境默认 REST 基址（Info.plist 未注入或未解析时的回退值）。
    public static func productionBaseURL(for region: AppRegion) -> URL {
        switch region {
        case .cn:
            URL(string: "https://api-cn.babygrowth.app")!
        case .os:
            URL(string: "https://api-os.babygrowth.app")!
        }
    }

    /// 生产环境默认 WebSocket 基址（Info.plist 未注入或未解析时的回退值）。
    public static func productionWebSocketBaseURL(for region: AppRegion) -> URL {
        switch region {
        case .cn:
            URL(string: "wss://ws-cn.babygrowth.app")!
        case .os:
            URL(string: "wss://ws-os.babygrowth.app")!
        }
    }

    /// 当前构建配置下的 REST 基址（Debug → localhost Mock，Staging → staging 域名，Release → 生产）。
    public var baseURL: URL {
        APIEnvironmentConfiguration.current().baseURL(for: self)
    }

    /// 当前构建配置下的 WebSocket 基址。
    public var webSocketBaseURL: URL {
        APIEnvironmentConfiguration.current().webSocketBaseURL(for: self)
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
