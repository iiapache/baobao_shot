import Foundation

/// 证书绑定编译开关 + config-svc Feature Flag 解析（OPT-01）。
public enum CertificatePinningConfigurationFactory {
    public static let featureFlagKey = "security.cert_pinning"
    public static let infoPlistEnabledKey = "CertificatePinningEnabled"

    private static let hostPlistKeys: [(host: String, plistKey: String)] = [
        ("api-cn.babygrowth.app", "CertificatePinHashesAPICN"),
        ("api-os.babygrowth.app", "CertificatePinHashesAPIOS"),
        ("ws-cn.babygrowth.app", "CertificatePinHashesWSCN"),
        ("ws-os.babygrowth.app", "CertificatePinHashesWSOS"),
    ]

    /// 单测 / Mock 强制走系统默认 TLS（stub 路径）。
    public static func resolve(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        featureFlagEnabled: Bool? = nil,
        enabledOverride: Bool? = nil,
        infoDictionary: [String: Any]? = nil
    ) -> CertificatePinningConfiguration {
        if forceStub {
            return .disabled
        }

        let info = infoDictionary ?? bundle.infoDictionary ?? [:]
        let enabled = enabledOverride
            ?? resolveEnabled(from: info, featureFlagEnabled: featureFlagEnabled)
        guard enabled else {
            return .disabled
        }

        let pinnedHashesByHost = resolvePinnedHashes(from: info)
        return CertificatePinningConfiguration(
            isEnabled: true,
            pinnedHashesByHost: pinnedHashesByHost
        )
    }

    public static func resolveEnabled(
        from bundle: Bundle = .main,
        featureFlagEnabled: Bool? = nil
    ) -> Bool {
        resolveEnabled(from: bundle.infoDictionary ?? [:], featureFlagEnabled: featureFlagEnabled)
    }

    static func resolveEnabled(
        from info: [String: Any],
        featureFlagEnabled: Bool? = nil
    ) -> Bool {
        if let featureFlagEnabled {
            return featureFlagEnabled
        }
        return parseBooleanPlistValue(info[infoPlistEnabledKey])
    }

    public static func resolvePinnedHashes(from bundle: Bundle = .main) -> [String: Set<String>] {
        resolvePinnedHashes(from: bundle.infoDictionary ?? [:])
    }

    static func resolvePinnedHashes(from info: [String: Any]) -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for entry in hostPlistKeys {
            let hashes = parseHashList(info[entry.plistKey])
            if !hashes.isEmpty {
                result[entry.host] = hashes
            }
        }
        return result
    }

    static func parseBooleanPlistValue(_ value: Any?) -> Bool {
        guard let raw = value as? String else { return false }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized.hasPrefix("$(") {
            return false
        }
        switch normalized {
        case "yes", "1", "true":
            return true
        case "no", "0", "false":
            return false
        default:
            return false
        }
    }

    static func parseHashList(_ value: Any?) -> Set<String> {
        guard let raw = value as? String else { return [] }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") {
            return []
        }
        let parts = trimmed.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return Set(parts.filter { !$0.isEmpty && !$0.hasPrefix("$(") })
    }
}

/// App 层统一 URLSession 工厂（REST / WebSocket / 下载共用）。
public enum NetworkSessionFactory {
    public static func makeSession(
        configuration: URLSessionConfiguration = .default,
        bundle: Bundle = .main,
        forceStub: Bool = false,
        featureFlagEnabled: Bool? = nil
    ) -> URLSession {
        let pinning = CertificatePinningConfigurationFactory.resolve(
            bundle: bundle,
            forceStub: forceStub,
            featureFlagEnabled: featureFlagEnabled
        )
        return CertificatePinningSessionFactory.makeSession(
            configuration: pinning,
            sessionConfiguration: configuration
        )
    }
}
