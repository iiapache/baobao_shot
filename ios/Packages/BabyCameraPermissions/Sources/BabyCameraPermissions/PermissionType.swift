import Foundation

/// 应用内统一的权限类型。
public enum PermissionType: String, CaseIterable, Sendable, Hashable {
    case camera
    case photoLibrary
    case notifications
    case locationWhenInUse
}

extension PermissionType {
    /// 设置页引导标题。
    public var settingsTitle: String {
        switch self {
        case .camera: return "需要相机权限"
        case .photoLibrary: return "需要相册权限"
        case .notifications: return "需要通知权限"
        case .locationWhenInUse: return "需要位置权限"
        }
    }

    /// 设置页引导说明。
    public var settingsMessage: String {
        switch self {
        case .camera:
            return "请在系统设置中允许「宝宝成长相机」使用相机，以便拍摄宝宝照片。"
        case .photoLibrary:
            return "请在系统设置中允许访问相册，以便导入与保存照片。"
        case .notifications:
            return "请在系统设置中开启通知，以便接收成长里程碑与家庭动态提醒。"
        case .locationWhenInUse:
            return "请在系统设置中允许使用位置，以便为照片记录拍摄地点。"
        }
    }

    /// SF Symbol 名称，用于引导 UI。
    public var systemImageName: String {
        switch self {
        case .camera: return "camera.fill"
        case .photoLibrary: return "photo.on.rectangle.angled"
        case .notifications: return "bell.badge.fill"
        case .locationWhenInUse: return "location.fill"
        }
    }
}
