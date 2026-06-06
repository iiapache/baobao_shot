import Foundation

/// 应用内统一的权限类型。
public enum PermissionType: String, CaseIterable, Sendable, Hashable {
    case camera
    case photoLibrary
    case notifications
    case locationWhenInUse
}
