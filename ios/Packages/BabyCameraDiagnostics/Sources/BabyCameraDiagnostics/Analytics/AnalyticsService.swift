import Foundation

/// 端侧埋点上报服务（design-ios §15.2）。
public enum AnalyticsService {
    public struct CommonFields: Sendable, Equatable {
        public var region: String
        public var userIdHash: String?
        public var babyIdHash: String?
        public var appVersion: String
        public var osVersion: String
        public var deviceModel: String
        public var sessionId: String

        public init(
            region: String = "CN",
            userIdHash: String? = nil,
            babyIdHash: String? = nil,
            appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: String = AnalyticsService.resolveDeviceModel(),
            sessionId: String = AnalyticsService.currentSessionId
        ) {
            self.region = region
            self.userIdHash = userIdHash
            self.babyIdHash = babyIdHash
            self.appVersion = appVersion
            self.osVersion = osVersion
            self.deviceModel = deviceModel
            self.sessionId = sessionId
        }
    }

    public typealias TrackHandler = @Sendable (String, [String: String], CommonFields) -> Void

    private static let sessionKey = "com.babycamera.analytics.sessionId"

    public nonisolated(unsafe) static var commonFields = CommonFields()

    /// 可注入的上报 hook；默认 DEBUG 打印。
    public nonisolated(unsafe) static var trackHandler: TrackHandler = { event, parameters, common in
        #if DEBUG
        print("[Analytics] event=\(event) params=\(parameters) common=\(common)")
        #endif
    }

    /// 批量上送阈值（§15.2）。
    public static let batchIntervalSeconds: TimeInterval = 30
    public static let batchMaxEvents: Int = 50

    public static func track(_ event: String, parameters: [String: String] = [:]) {
        guard AnalyticsEventCatalog.contains(event) else {
            #if DEBUG
            print("[Analytics] WARNING orphan event (not in catalog): \(event)")
            #endif
            return
        }
        trackHandler(event, parameters, commonFields)
    }

    public static func updateCommonFields(_ transform: (inout CommonFields) -> Void) {
        var fields = commonFields
        transform(&fields)
        commonFields = fields
    }

    private static var currentSessionId: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: sessionKey) {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: sessionKey)
        return generated
    }

    private static func resolveDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
        return identifier
    }
}
