import Foundation

/// 备份目标抽象；ICloudProvider（T6.3）、PhotosProvider（T6.4）与 BaiduPanProvider（T6.5）已实现。
public protocol BackupProvider: Sendable {
    var kind: BackupKind { get }

    func authorize() async throws
    func quota() async throws -> BackupQuota
    func upload(_ item: BackupItem) async throws -> BackupReceipt
    func list(after cursor: String?) async throws -> BackupPage
    func revoke() async throws
}
