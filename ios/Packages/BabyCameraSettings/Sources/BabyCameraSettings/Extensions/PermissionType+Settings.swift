import BabyCameraPermissions
import DesignSystem
import Foundation

extension PermissionType {
    var privacySettingsLabel: String {
        switch self {
        case .camera:
            return L10n.string("settings.permission.camera")
        case .photoLibrary:
            return L10n.string("settings.permission.photo_library")
        case .notifications:
            return L10n.string("settings.permission.notifications")
        case .locationWhenInUse:
            return L10n.string("settings.permission.location")
        }
    }

    var privacySettingsIcon: String {
        switch self {
        case .camera:
            return "camera.fill"
        case .photoLibrary:
            return "photo.on.rectangle.angled"
        case .notifications:
            return "bell.badge.fill"
        case .locationWhenInUse:
            return "location.fill"
        }
    }
}
