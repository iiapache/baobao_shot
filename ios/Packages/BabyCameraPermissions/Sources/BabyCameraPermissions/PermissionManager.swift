import AVFoundation
import CoreLocation
import Foundation
import Photos
import UserNotifications

/// 统一权限查询与申请入口。
@MainActor
public protocol PermissionManager {
    func status(for type: PermissionType) -> PermissionStatus
    func requestAuthorization(for type: PermissionType) async -> PermissionStatus
    func settingsURL(for type: PermissionType) -> URL?
    var openSettingsURL: URL? { get }
    func refreshNotificationStatus() async
}

public extension PermissionManager {
    /// 系统设置页 URL；仅在对应权限为 `denied` 时返回，用于引导用户手动开启。
    func settingsURL(for type: PermissionType) -> URL? {
        guard status(for: type).isDenied else { return nil }
        return openSettingsURL
    }
}

/// 默认实现，封装 AVFoundation / Photos / UserNotifications / CoreLocation。
@MainActor
public final class DefaultPermissionManager: PermissionManager {
    private let cameraService: any CameraPermissionChecking
    private let photoLibraryService: any PhotoLibraryPermissionChecking
    private let notificationService: any NotificationPermissionChecking
    private let locationService: any LocationPermissionChecking
    private let settingsURLProvider: any SettingsURLProviding
    private var notificationStatusCache: PermissionStatus = .notDetermined

    public init(
        cameraService: any CameraPermissionChecking = LiveCameraPermissionService(),
        photoLibraryService: any PhotoLibraryPermissionChecking = LivePhotoLibraryPermissionService(),
        notificationService: any NotificationPermissionChecking = LiveNotificationPermissionService(),
        locationService: any LocationPermissionChecking = LiveLocationPermissionService(),
        settingsURLProvider: any SettingsURLProviding = LiveSettingsURLProvider()
    ) {
        self.cameraService = cameraService
        self.photoLibraryService = photoLibraryService
        self.notificationService = notificationService
        self.locationService = locationService
        self.settingsURLProvider = settingsURLProvider
    }

    public func refreshNotificationStatus() async {
        let status = await notificationService.authorizationStatus()
        notificationStatusCache = Self.mapUN(status)
    }

    public func status(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .camera:
            return Self.mapAV(cameraService.authorizationStatus())
        case .photoLibrary:
            return Self.mapPH(photoLibraryService.authorizationStatus())
        case .notifications:
            return notificationStatusCache
        case .locationWhenInUse:
            return Self.mapCL(locationService.authorizationStatus())
        }
    }

    public func requestAuthorization(for type: PermissionType) async -> PermissionStatus {
        switch type {
        case .camera:
            let current = Self.mapAV(cameraService.authorizationStatus())
            guard current == .notDetermined else { return current }
            let granted = await cameraService.requestAccess()
            return granted ? .authorized : Self.mapAV(cameraService.authorizationStatus())

        case .photoLibrary:
            let current = Self.mapPH(photoLibraryService.authorizationStatus())
            guard current == .notDetermined else { return current }
            let result = await photoLibraryService.requestAuthorization()
            return Self.mapPH(result)

        case .notifications:
            let current = await notificationService.authorizationStatus()
            let mapped = Self.mapUN(current)
            guard mapped == .notDetermined else {
                notificationStatusCache = mapped
                return mapped
            }
            _ = await notificationService.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshNotificationStatus()
            return notificationStatusCache

        case .locationWhenInUse:
            let current = Self.mapCL(locationService.authorizationStatus())
            guard current == .notDetermined else { return current }
            let result = await locationService.requestWhenInUseAuthorization()
            return Self.mapCL(result)
        }
    }

    public func settingsURL(for type: PermissionType) -> URL? {
        guard status(for: type).isDenied else { return nil }
        return settingsURLProvider.openSettingsURL
    }

    public var openSettingsURL: URL? {
        settingsURLProvider.openSettingsURL
    }

    // MARK: - Status mapping

    static func mapAV(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .denied
        }
    }

    static func mapPH(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized, .limited: return .authorized
        @unknown default: return .denied
        }
    }

    static func mapUN(_ status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .authorized
        @unknown default: return .denied
        }
    }

    static func mapCL(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        @unknown default: return .denied
        }
    }

}
