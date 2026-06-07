import Foundation

/// 百度网盘 OAuth 运行模式：stub（单测 / Debug 默认）或 live（ASWebAuthenticationSession）。
public enum BaiduPanOAuthMode: String, Sendable, Equatable {
    case stub
    case live
}

public enum BaiduPanOAuthConfiguration {
    public static let useLiveOAuthInfoPlistKey = "BaiduPanUseLiveOAuth"
    public static let clientIDInfoPlistKey = "BaiduPanClientID"
    public static let redirectURIInfoPlistKey = "BaiduPanRedirectURI"
    public static let clientSecretInfoPlistKey = "BaiduPanClientSecret"

    public static let defaultClientID = "babycamera-baidu-client-id"
    public static let defaultRedirectURI = "babycamera://oauth/baidu"
    public static let defaultScope = "basic,netdisk"

    public static let authorizeURL = URL(string: "https://openapi.baidu.com/oauth/2.0/authorize")!
    public static let tokenURL = URL(string: "https://openapi.baidu.com/oauth/2.0/token")!
    public static let loggedInUserURL = URL(string: "https://openapi.baidu.com/rest/2.0/passport/users/getLoggedInUser")!

    public static func useLiveOAuthFromInfoPlist(bundle: Bundle = .main) -> Bool {
        parseBool(bundle.infoDictionary?[useLiveOAuthInfoPlistKey] as? String, defaultValue: false)
    }

    public static func clientIDFromInfoPlist(bundle: Bundle = .main) -> String {
        parseNonEmpty(bundle.infoDictionary?[clientIDInfoPlistKey] as? String) ?? defaultClientID
    }

    public static func redirectURIFromInfoPlist(bundle: Bundle = .main) -> String {
        parseNonEmpty(bundle.infoDictionary?[redirectURIInfoPlistKey] as? String) ?? defaultRedirectURI
    }

    public static func clientSecretFromInfoPlist(bundle: Bundle = .main) -> String? {
        parseNonEmpty(bundle.infoDictionary?[clientSecretInfoPlistKey] as? String)
    }

    public static func resolveMode(
        bundle: Bundle = .main,
        forceStub: Bool = false,
        useLiveOAuthOverride: Bool? = nil
    ) -> BaiduPanOAuthMode {
        if forceStub {
            return .stub
        }
        let wantsLive = useLiveOAuthOverride ?? useLiveOAuthFromInfoPlist(bundle: bundle)
        return wantsLive ? .live : .stub
    }

    public static func callbackURLScheme(for redirectURI: String) -> String? {
        guard let components = URLComponents(string: redirectURI),
              let scheme = components.scheme,
              !scheme.isEmpty
        else {
            return nil
        }
        return scheme
    }

    public static func makeAuthorizeURL(
        clientID: String,
        redirectURI: String,
        scope: String = defaultScope,
        state: String
    ) -> URL? {
        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "display", value: "mobile"),
            URLQueryItem(name: "state", value: state),
        ]
        return components?.url
    }

    private static func parseBool(_ raw: String?, defaultValue: Bool) -> Bool {
        guard let raw else { return defaultValue }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized.hasPrefix("$(") {
            return defaultValue
        }
        switch normalized {
        case "yes", "1", "true":
            return true
        case "no", "0", "false":
            return false
        default:
            return defaultValue
        }
    }

    private static func parseNonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") {
            return nil
        }
        return trimmed
    }
}
