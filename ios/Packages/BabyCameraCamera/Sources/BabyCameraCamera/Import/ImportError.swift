import Foundation

/// 系统相册导入错误。
public enum ImportError: Error, Equatable, Sendable {
    /// 文件内无 `DateTimeOriginal`，禁止导入。
    case missingEXIF
    /// 拍摄早于所选宝宝出生日（V1 暂禁导入）。
    case beforeBirthDate
    case emptyBabyIds
    case emptySelection
    case loadFailed(String)
    case fileWriteFailed(String)
}
