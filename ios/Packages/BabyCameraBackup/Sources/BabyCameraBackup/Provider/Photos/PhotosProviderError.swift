import Foundation

public enum PhotosProviderError: Error, Equatable, Sendable {
    case authorizationDenied
    case authorizationRestricted
    case fileNotFound(path: String)
    case writeFailed(reason: String)
}

extension PhotosProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "未获得「添加照片」权限。请在「设置 → 隐私与安全性 → 照片」中允许本 App 添加照片。"
        case .authorizationRestricted:
            return "系统相册访问受限，请检查屏幕使用时间或设备管理策略。"
        case let .fileNotFound(path):
            return "待备份文件不存在：\(path)"
        case let .writeFailed(reason):
            return "写入系统相册失败：\(reason)"
        }
    }
}
