import Foundation

/// 从 Info.plist（xcconfig → build setting 注入）读取各区域 API / WebSocket 基址。
public struct APIEnvironmentConfiguration: Sendable, Equatable {
    public let cnAPIBaseURL: URL
    public let osAPIBaseURL: URL
    public let cnWebSocketBaseURL: URL
    public let osWebSocketBaseURL: URL

    public init(
        cnAPIBaseURL: URL,
        osAPIBaseURL: URL,
        cnWebSocketBaseURL: URL,
        osWebSocketBaseURL: URL
    ) {
        self.cnAPIBaseURL = cnAPIBaseURL
        self.osAPIBaseURL = osAPIBaseURL
        self.cnWebSocketBaseURL = cnWebSocketBaseURL
        self.osWebSocketBaseURL = osWebSocketBaseURL
    }

    public init(bundle: Bundle = .main) {
        self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) {
        cnAPIBaseURL = Self.url(from: infoDictionary["APIBaseURLCN"]) ?? AppRegion.productionBaseURL(for: .cn)
        osAPIBaseURL = Self.url(from: infoDictionary["APIBaseURLOS"]) ?? AppRegion.productionBaseURL(for: .os)
        cnWebSocketBaseURL = Self.url(from: infoDictionary["WebSocketBaseURLCN"]) ?? AppRegion.productionWebSocketBaseURL(for: .cn)
        osWebSocketBaseURL = Self.url(from: infoDictionary["WebSocketBaseURLOS"]) ?? AppRegion.productionWebSocketBaseURL(for: .os)
    }

    public static func current(bundle: Bundle = .main) -> APIEnvironmentConfiguration {
        if let override = testingOverride {
            return override
        }
        if let cached = cachedFromMainBundle {
            return cached
        }
        let configuration = APIEnvironmentConfiguration(bundle: bundle)
        if bundle == .main {
            cachedFromMainBundle = configuration
        }
        return configuration
    }

    public func baseURL(for region: AppRegion) -> URL {
        switch region {
        case .cn:
            cnAPIBaseURL
        case .os:
            osAPIBaseURL
        }
    }

    public func webSocketBaseURL(for region: AppRegion) -> URL {
        switch region {
        case .cn:
            cnWebSocketBaseURL
        case .os:
            osWebSocketBaseURL
        }
    }

    private static var cachedFromMainBundle: APIEnvironmentConfiguration?
    private static var testingOverride: APIEnvironmentConfiguration?

    #if DEBUG
    public static func setTestingOverride(_ configuration: APIEnvironmentConfiguration?) {
        testingOverride = configuration
    }

    public static func resetCachedConfiguration() {
        cachedFromMainBundle = nil
        testingOverride = nil
    }
    #endif

    private static func url(from value: Any?) -> URL? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return URL(string: trimmed)
    }
}
