import AVFoundation
import CoreLocation
import Foundation
import Photos
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Injectable service protocols

public protocol CameraPermissionChecking: Sendable {
    func authorizationStatus() -> AVAuthorizationStatus
    func requestAccess() async -> Bool
}

public protocol PhotoLibraryPermissionChecking: Sendable {
    func authorizationStatus() -> PHAuthorizationStatus
    func requestAuthorization() async -> PHAuthorizationStatus
}

public protocol NotificationPermissionChecking: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async -> Bool
}

public protocol LocationPermissionChecking: AnyObject, Sendable {
    func authorizationStatus() -> CLAuthorizationStatus
    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus
}

public protocol SettingsURLProviding: Sendable {
    var openSettingsURL: URL? { get }
}

// MARK: - Live implementations

public struct LiveCameraPermissionService: CameraPermissionChecking {
    public init() {}

    public func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    public func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

public struct LivePhotoLibraryPermissionService: PhotoLibraryPermissionChecking {
    private let accessLevel: PHAccessLevel

    public init(accessLevel: PHAccessLevel = .readWrite) {
        self.accessLevel = accessLevel
    }

    public func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: accessLevel)
    }

    public func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: accessLevel)
    }
}

public struct LiveNotificationPermissionService: NotificationPermissionChecking {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    public func requestAuthorization(options: UNAuthorizationOptions) async -> Bool {
        do {
            return try await center.requestAuthorization(options: options)
        } catch {
            return false
        }
    }
}

@MainActor
public final class LiveLocationPermissionService: NSObject, LocationPermissionChecking, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    public init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        super.init()
        self.manager.delegate = self
    }

    public func authorizationStatus() -> CLAuthorizationStatus {
        manager.authorizationStatus
    }

    public func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        let current = authorizationStatus()
        guard current == .notDetermined else {
            return current
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: manager.authorizationStatus)
    }
}

public struct LiveSettingsURLProvider: SettingsURLProviding {
    public init() {}

    public var openSettingsURL: URL? {
        #if canImport(UIKit)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}
