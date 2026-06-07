import Foundation

public enum BackupKind: String, Sendable, Codable, CaseIterable, Equatable {
    case iCloud
    case photos
    case baiduPan
}
