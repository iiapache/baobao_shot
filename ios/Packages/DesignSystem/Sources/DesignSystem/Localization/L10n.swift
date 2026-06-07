import Foundation
import SwiftUI

/// 主 App `Localizable.xcstrings` 语义化 key 查找（T7.17）。
/// SPM 模块通过 `Bundle.main` 读取；单元测试回退至 `Bundle.module` 内嵌 `zh-Hans` 字符串表。
public enum L10n {
    private static let table = "Localizable"

    private static var bundles: [Bundle] {
        [Bundle.main, Bundle.module]
    }

    /// 本地化字符串（支持 `String(format:)` 占位符）。
    public static func string(_ key: String, _ args: CVarArg...) -> String {
        let format = lookup(key)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: Locale.current, arguments: args)
    }

    /// SwiftUI `Text` 便捷构造。
    public static func text(_ key: String, _ args: CVarArg...) -> Text {
        Text(string(key, args))
    }

    /// `LocalizedStringKey` 包装（语义 key → 运行时解析为当前语言文案）。
    public static func localizedKey(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(string(key))
    }

    private static func lookup(_ key: String) -> String {
        for bundle in bundles {
            let value = bundle.localizedString(forKey: key, value: nil, table: table)
            if value != key { return value }
        }
        return key
    }
}
