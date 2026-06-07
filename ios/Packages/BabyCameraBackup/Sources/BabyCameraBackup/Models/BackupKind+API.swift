import Foundation

public extension BackupKind {
    /// 与 auth-family-svc `/v1/backup/providers` 的 `kind` 字段对齐。
    var apiKindValue: String {
        switch self {
        case .iCloud: return "icloud"
        case .photos: return "photos"
        case .baiduPan: return "baidu_pan"
        }
    }

    init?(apiKindValue: String) {
        switch apiKindValue {
        case "icloud": self = .iCloud
        case "photos": self = .photos
        case "baidu_pan": self = .baiduPan
        default: return nil
        }
    }
}
