import Foundation

/// 权限三态（含系统受限态）的统一表达。
public enum PermissionStatus: Equatable, Sendable, Hashable {
    case notDetermined
    case denied
    case authorized
    case restricted
}

extension PermissionStatus {
    /// 是否已明确拒绝（可向用户引导跳转系统设置）。
    public var isDenied: Bool {
        self == .denied
    }

    /// 是否已授权（含受限设备上的可用授权）。
    public var isAuthorized: Bool {
        self == .authorized
    }

    /// 是否尚未请求过授权。
    public var isNotDetermined: Bool {
        self == .notDetermined
    }
}
