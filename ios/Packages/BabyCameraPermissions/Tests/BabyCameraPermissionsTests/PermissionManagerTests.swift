import AVFoundation
import CoreLocation
import Photos
import UserNotifications
import XCTest
@testable import BabyCameraPermissions

// MARK: - Mocks

final class MockCameraPermissionService: CameraPermissionChecking, @unchecked Sendable {
    var status: AVAuthorizationStatus = .notDetermined
    var requestResult = true
    private(set) var requestCount = 0

    func authorizationStatus() -> AVAuthorizationStatus { status }

    func requestAccess() async -> Bool {
        requestCount += 1
        status = requestResult ? .authorized : .denied
        return requestResult
    }
}

final class MockPhotoLibraryPermissionService: PhotoLibraryPermissionChecking, @unchecked Sendable {
    var status: PHAuthorizationStatus = .notDetermined
    private(set) var requestCount = 0

    func authorizationStatus() -> PHAuthorizationStatus { status }

    func requestAuthorization() async -> PHAuthorizationStatus {
        requestCount += 1
        status = .authorized
        return status
    }
}

final class MockNotificationPermissionService: NotificationPermissionChecking, @unchecked Sendable {
    var status: UNAuthorizationStatus = .notDetermined
    var requestResult = true
    private(set) var requestCount = 0

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization(options: UNAuthorizationOptions) async -> Bool {
        requestCount += 1
        status = requestResult ? .authorized : .denied
        return requestResult
    }
}

final class MockLocationPermissionService: LocationPermissionChecking, @unchecked Sendable {
    var status: CLAuthorizationStatus = .notDetermined
    private(set) var requestCount = 0

    func authorizationStatus() -> CLAuthorizationStatus { status }

    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        requestCount += 1
        status = .authorizedWhenInUse
        return status
    }
}

struct MockSettingsURLProvider: SettingsURLProviding {
    let url: URL?

    var openSettingsURL: URL? { url }
}

@MainActor
private enum TestFixtures {
    static func makeManager(
        camera: MockCameraPermissionService = MockCameraPermissionService(),
        photoLibrary: MockPhotoLibraryPermissionService = MockPhotoLibraryPermissionService(),
        notifications: MockNotificationPermissionService = MockNotificationPermissionService(),
        location: MockLocationPermissionService = MockLocationPermissionService(),
        settingsURL: URL? = URL(string: "app-settings://")
    ) -> (DefaultPermissionManager, Mocks) {
        let mocks = Mocks(
            camera: camera,
            photoLibrary: photoLibrary,
            notifications: notifications,
            location: location
        )
        let manager = DefaultPermissionManager(
            cameraService: camera,
            photoLibraryService: photoLibrary,
            notificationService: notifications,
            locationService: location,
            settingsURLProvider: MockSettingsURLProvider(url: settingsURL)
        )
        return (manager, mocks)
    }

    struct Mocks {
        let camera: MockCameraPermissionService
        let photoLibrary: MockPhotoLibraryPermissionService
        let notifications: MockNotificationPermissionService
        let location: MockLocationPermissionService
    }
}

// MARK: - Tests

@MainActor
final class PermissionStatusMappingTests: XCTestCase {
    func testAVAuthorizationStatusMapping() {
        XCTAssertEqual(DefaultPermissionManager.mapAV(.notDetermined), .notDetermined)
        XCTAssertEqual(DefaultPermissionManager.mapAV(.denied), .denied)
        XCTAssertEqual(DefaultPermissionManager.mapAV(.restricted), .restricted)
        XCTAssertEqual(DefaultPermissionManager.mapAV(.authorized), .authorized)
    }

    func testPHAuthorizationStatusMapping() {
        XCTAssertEqual(DefaultPermissionManager.mapPH(.notDetermined), .notDetermined)
        XCTAssertEqual(DefaultPermissionManager.mapPH(.denied), .denied)
        XCTAssertEqual(DefaultPermissionManager.mapPH(.restricted), .restricted)
        XCTAssertEqual(DefaultPermissionManager.mapPH(.authorized), .authorized)
        XCTAssertEqual(DefaultPermissionManager.mapPH(.limited), .authorized)
    }

    func testUNAuthorizationStatusMapping() {
        XCTAssertEqual(DefaultPermissionManager.mapUN(.notDetermined), .notDetermined)
        XCTAssertEqual(DefaultPermissionManager.mapUN(.denied), .denied)
        XCTAssertEqual(DefaultPermissionManager.mapUN(.authorized), .authorized)
        XCTAssertEqual(DefaultPermissionManager.mapUN(.provisional), .authorized)
        XCTAssertEqual(DefaultPermissionManager.mapUN(.ephemeral), .authorized)
    }

    func testCLAuthorizationStatusMapping() {
        XCTAssertEqual(DefaultPermissionManager.mapCL(.notDetermined), .notDetermined)
        XCTAssertEqual(DefaultPermissionManager.mapCL(.denied), .denied)
        XCTAssertEqual(DefaultPermissionManager.mapCL(.restricted), .restricted)
        XCTAssertEqual(DefaultPermissionManager.mapCL(.authorizedWhenInUse), .authorized)
        XCTAssertEqual(DefaultPermissionManager.mapCL(.authorizedAlways), .authorized)
    }
}

@MainActor
final class PermissionManagerTests: XCTestCase {
    func testCameraRequestAuthorizationFromNotDetermined() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.camera.status = .notDetermined
        mocks.camera.requestResult = true

        let result = await manager.requestAuthorization(for: .camera)

        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(mocks.camera.requestCount, 1)
        XCTAssertEqual(manager.status(for: .camera), .authorized)
    }

    func testCameraRequestAuthorizationDenied() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.camera.status = .notDetermined
        mocks.camera.requestResult = false

        let result = await manager.requestAuthorization(for: .camera)

        XCTAssertEqual(result, .denied)
        XCTAssertEqual(manager.status(for: .camera), .denied)
    }

    func testCameraSkipsRequestWhenAlreadyDetermined() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.camera.status = .denied

        let result = await manager.requestAuthorization(for: .camera)

        XCTAssertEqual(result, .denied)
        XCTAssertEqual(mocks.camera.requestCount, 0)
    }

    func testPhotoLibraryRequestAuthorization() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.photoLibrary.status = .notDetermined

        let result = await manager.requestAuthorization(for: .photoLibrary)

        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(mocks.photoLibrary.requestCount, 1)
    }

    func testNotificationRequestAuthorization() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.notifications.status = .notDetermined
        mocks.notifications.requestResult = true

        let result = await manager.requestAuthorization(for: .notifications)

        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(mocks.notifications.requestCount, 1)
        XCTAssertEqual(manager.status(for: .notifications), .authorized)
    }

    func testLocationRequestAuthorization() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.location.status = .notDetermined

        let result = await manager.requestAuthorization(for: .locationWhenInUse)

        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(mocks.location.requestCount, 1)
        XCTAssertEqual(manager.status(for: .locationWhenInUse), .authorized)
    }

    func testRestrictedStatusIsReported() {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.camera.status = .restricted

        XCTAssertEqual(manager.status(for: .camera), .restricted)
        XCTAssertNil(manager.settingsURL(for: .camera))
    }

    func testSettingsURLOnlyWhenDenied() {
        let settingsURL = URL(string: "app-settings://")
        let (manager, mocks) = TestFixtures.makeManager(settingsURL: settingsURL)

        mocks.camera.status = .denied
        XCTAssertEqual(manager.settingsURL(for: .camera), settingsURL)
        XCTAssertEqual(manager.openSettingsURL, settingsURL)

        mocks.camera.status = .authorized
        XCTAssertNil(manager.settingsURL(for: .camera))

        mocks.camera.status = .notDetermined
        XCTAssertNil(manager.settingsURL(for: .camera))
    }

    func testRefreshNotificationStatus() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.notifications.status = .denied

        await manager.refreshNotificationStatus()

        XCTAssertEqual(manager.status(for: .notifications), .denied)
    }

    func testPermissionTypeCases() {
        XCTAssertEqual(PermissionType.allCases.count, 4)
        XCTAssertTrue(PermissionType.allCases.contains(.camera))
        XCTAssertTrue(PermissionType.allCases.contains(.photoLibrary))
        XCTAssertTrue(PermissionType.allCases.contains(.notifications))
        XCTAssertTrue(PermissionType.allCases.contains(.locationWhenInUse))
    }
}
