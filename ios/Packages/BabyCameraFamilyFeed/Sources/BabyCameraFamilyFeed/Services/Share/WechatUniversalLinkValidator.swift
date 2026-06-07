import Foundation

/// 微信 OpenSDK Universal Link（UA）格式校验（T5.13）。
public enum WechatUniversalLinkValidator {
    /// 校验 Universal Link 是否满足微信开放平台要求：HTTPS、有 host、路径非空且以 `/` 结尾、无 fragment。
    public static func validate(_ link: String) -> Bool {
        guard let url = URL(string: link),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host,
              !host.isEmpty,
              url.fragment == nil else {
            return false
        }

        let path = url.path
        return !path.isEmpty && path.hasSuffix("/")
    }
}
