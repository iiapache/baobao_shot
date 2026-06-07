import AVFoundation
import BabyCameraNetwork
import BabyCameraPermissions
import CoreLocation
import DesignSystem
import Photos
import UserNotifications
import XCTest
@testable import BabyCameraSettings

@MainActor
final class PrivacySettingsViewModelTests: XCTestCase {
    func testRefreshLoadsPermissionStatuses() async {
        let camera = MockCameraPermissionService()
        camera.status = .authorized
        let photo = MockPhotoLibraryPermissionService()
        photo.status = .denied
        let manager = makeManager(camera: camera, photoLibrary: photo)

        let viewModel = PrivacySettingsViewModel(
            profile: UserProfile(
                nickname: "测试",
                avatarUrl: nil,
                region: "cn",
                consents: UserConsents(childData: true)
            ),
            permissionManager: manager
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.statusLabel(for: .camera), L10n.string("settings.permission.authorized"))
        XCTAssertEqual(viewModel.statusLabel(for: .photoLibrary), L10n.string("settings.permission.denied"))
        XCTAssertTrue(viewModel.hasChildDataConsent)
        XCTAssertTrue(viewModel.needsSettingsPrompt(for: .photoLibrary))
        XCTAssertFalse(viewModel.needsSettingsPrompt(for: .camera))
    }

    func testChildConsentMissing() async {
        let viewModel = PrivacySettingsViewModel(
            profile: UserProfile(
                nickname: "测试",
                avatarUrl: nil,
                region: "cn",
                consents: UserConsents(childData: false)
            ),
            permissionManager: makeManager()
        )

        await viewModel.refresh()

        XCTAssertFalse(viewModel.hasChildDataConsent)
    }

    private func makeManager(
        camera: MockCameraPermissionService = MockCameraPermissionService(),
        photoLibrary: MockPhotoLibraryPermissionService = MockPhotoLibraryPermissionService(),
        notifications: MockNotificationPermissionService = MockNotificationPermissionService(),
        location: MockLocationPermissionService = MockLocationPermissionService()
    ) -> DefaultPermissionManager {
        DefaultPermissionManager(
            cameraService: camera,
            photoLibraryService: photoLibrary,
            notificationService: notifications,
            locationService: location,
            settingsURLProvider: MockSettingsURLProvider(url: URL(string: "app-settings:"))
        )
    }
}

// Reuse permission test mocks from BabyCameraPermissions tests pattern.
@MainActor
final class MockCameraPermissionService: CameraPermissionChecking, @unchecked Sendable {
    var status: AVAuthorizationStatus = .notDetermined
    var requestResult = true

    func authorizationStatus() -> AVAuthorizationStatus { status }
    func requestAccess() async -> Bool { requestResult }
}

@MainActor
final class MockPhotoLibraryPermissionService: PhotoLibraryPermissionChecking, @unchecked Sendable {
    var status: PHAuthorizationStatus = .notDetermined
    var requestResult: PHAuthorizationStatus = .authorized

    func authorizationStatus() -> PHAuthorizationStatus { status }
    func requestAuthorization() async -> PHAuthorizationStatus { requestResult }
}

@MainActor
final class MockNotificationPermissionService: NotificationPermissionChecking, @unchecked Sendable {
    var status: UNAuthorizationStatus = .notDetermined
    var requestResult = true

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async -> Bool { requestResult }
}

@MainActor
final class MockLocationPermissionService: LocationPermissionChecking, @unchecked Sendable {
    var status: CLAuthorizationStatus = .notDetermined
    var requestResult = true

    func authorizationStatus() -> CLAuthorizationStatus { status }
    func requestAuthorization() async -> Bool { requestResult }
}

struct MockSettingsURLProvider: SettingsURLProviding {
    let url: URL?
    var openSettingsURL: URL? { url }
}
