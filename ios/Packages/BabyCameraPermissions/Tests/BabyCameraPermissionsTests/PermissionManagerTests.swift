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
    var requestResult: PHAuthorizationStatus = .authorized
    private(set) var requestCount = 0

    func authorizationStatus() -> PHAuthorizationStatus { status }

    func requestAuthorization() async -> PHAuthorizationStatus {
        requestCount += 1
        status = requestResult
        return requestResult
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
    var requestResult: CLAuthorizationStatus = .authorizedWhenInUse
    private(set) var requestCount = 0

    func authorizationStatus() -> CLAuthorizationStatus { status }

    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        requestCount += 1
        status = requestResult
        return requestResult
    }
}

struct MockSettingsURLProvider: SettingsURLProviding {
    let url: URL?

    var openSettingsURL: URL? { url }
}

struct MockSettingsRouter: SettingsOpening {
    var canOpen = true
    private(set) var openedURL: URL?

    @MainActor
    func open(_ url: URL) -> Bool {
        guard canOpen else { return false }
        openedURL = url
        return true
    }
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

    func testPhotoLibraryDeniedAfterRequest() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.photoLibrary.status = .notDetermined
        mocks.photoLibrary.requestResult = .denied

        let result = await manager.requestAuthorization(for: .photoLibrary)

        XCTAssertEqual(result, .denied)
        XCTAssertEqual(mocks.photoLibrary.requestCount, 1)
    }

    func testPhotoLibrarySkipsRequestWhenAlreadyAuthorized() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.photoLibrary.status = .authorized

        let result = await manager.requestAuthorization(for: .photoLibrary)

        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(mocks.photoLibrary.requestCount, 0)
    }

    func testPhotoLibraryLimitedMapsToAuthorized() {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.photoLibrary.status = .limited

        XCTAssertEqual(manager.status(for: .photoLibrary), .authorized)
        XCTAssertNil(manager.settingsURL(for: .photoLibrary))
    }

    func testPhotoLibraryRestrictedStatus() {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.photoLibrary.status = .restricted

        XCTAssertEqual(manager.status(for: .photoLibrary), .restricted)
        XCTAssertNil(manager.settingsURL(for: .photoLibrary))
    }

    func testNotificationDeniedAfterRequest() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.notifications.status = .notDetermined
        mocks.notifications.requestResult = false

        let result = await manager.requestAuthorization(for: .notifications)

        XCTAssertEqual(result, .denied)
        XCTAssertEqual(mocks.notifications.requestCount, 1)
    }

    func testNotificationSkipsRequestWhenAlreadyAuthorized() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.notifications.status = .authorized

        let result = await manager.requestAuthorization(for: .notifications)

        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(mocks.notifications.requestCount, 0)
    }

    func testLocationDeniedAfterRequest() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.location.status = .notDetermined
        mocks.location.requestResult = .denied

        let result = await manager.requestAuthorization(for: .locationWhenInUse)

        XCTAssertEqual(result, .denied)
        XCTAssertEqual(mocks.location.requestCount, 1)
    }

    func testLocationSkipsRequestWhenAlreadyDenied() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.location.status = .denied

        let result = await manager.requestAuthorization(for: .locationWhenInUse)

        XCTAssertEqual(result, .denied)
        XCTAssertEqual(mocks.location.requestCount, 0)
    }

    func testLocationRestrictedStatus() {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.location.status = .restricted

        XCTAssertEqual(manager.status(for: .locationWhenInUse), .restricted)
        XCTAssertNil(manager.settingsURL(for: .locationWhenInUse))
    }

    func testSettingsURLOnlyWhenDeniedForAllTypes() {
        let settingsURL = URL(string: "app-settings://")
        let (manager, mocks) = TestFixtures.makeManager(settingsURL: settingsURL)

        for type in PermissionType.allCases {
            switch type {
            case .camera:
                mocks.camera.status = .denied
            case .photoLibrary:
                mocks.photoLibrary.status = .denied
            case .notifications:
                mocks.notifications.status = .denied
            case .locationWhenInUse:
                mocks.location.status = .denied
            }

            XCTAssertEqual(manager.settingsURL(for: type), settingsURL, "Expected settings URL for denied \(type)")
        }
    }

    func testSettingsURLNilWhenProviderReturnsNil() {
        let (manager, mocks) = TestFixtures.makeManager(settingsURL: nil)
        mocks.camera.status = .denied

        XCTAssertNil(manager.settingsURL(for: .camera))
    }

    func testOpenSettingsWhenDenied() {
        let settingsURL = URL(string: "app-settings://")
        let (manager, mocks) = TestFixtures.makeManager(settingsURL: settingsURL)
        let router = MockSettingsRouter()
        mocks.camera.status = .denied

        XCTAssertTrue(manager.openSettings(for: .camera, using: router))
        XCTAssertEqual(router.openedURL, settingsURL)
    }

    func testOpenSettingsReturnsFalseWhenAuthorized() {
        let (manager, mocks) = TestFixtures.makeManager()
        let router = MockSettingsRouter()
        mocks.camera.status = .authorized

        XCTAssertFalse(manager.openSettings(for: .camera, using: router))
        XCTAssertNil(router.openedURL)
    }

    func testOpenSettingsReturnsFalseWhenRouterCannotOpen() {
        let settingsURL = URL(string: "app-settings://")
        let (manager, mocks) = TestFixtures.makeManager(settingsURL: settingsURL)
        var router = MockSettingsRouter()
        router.canOpen = false
        mocks.camera.status = .denied

        XCTAssertFalse(manager.openSettings(for: .camera, using: router))
        XCTAssertNil(router.openedURL)
    }
}

@MainActor
final class PermissionStatusPropertyTests: XCTestCase {
    func testPermissionStatusFlags() {
        XCTAssertTrue(PermissionStatus.denied.isDenied)
        XCTAssertFalse(PermissionStatus.authorized.isDenied)
        XCTAssertFalse(PermissionStatus.notDetermined.isDenied)
        XCTAssertFalse(PermissionStatus.restricted.isDenied)

        XCTAssertTrue(PermissionStatus.authorized.isAuthorized)
        XCTAssertFalse(PermissionStatus.denied.isAuthorized)

        XCTAssertTrue(PermissionStatus.notDetermined.isNotDetermined)
        XCTAssertFalse(PermissionStatus.denied.isNotDetermined)
    }
}

@MainActor
final class PermissionRoutingTests: XCTestCase {
    func testEnsureAuthorizedRequestsWhenNotDetermined() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.camera.status = .notDetermined
        let routing = PermissionRouting(manager: manager)

        let result = await routing.ensureAuthorized(.camera)

        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(mocks.camera.requestCount, 1)
    }

    func testEnsureAuthorizedSkipsWhenAlreadyDenied() async {
        let (manager, mocks) = TestFixtures.makeManager()
        mocks.camera.status = .denied
        let routing = PermissionRouting(manager: manager)

        let result = await routing.ensureAuthorized(.camera)

        XCTAssertEqual(result, .denied)
        XCTAssertEqual(mocks.camera.requestCount, 0)
    }

    func testNeedsSettingsPromptOnlyWhenDenied() {
        let (manager, mocks) = TestFixtures.makeManager()
        let routing = PermissionRouting(manager: manager)

        mocks.camera.status = .denied
        XCTAssertTrue(routing.needsSettingsPrompt(for: .camera))

        mocks.camera.status = .authorized
        XCTAssertFalse(routing.needsSettingsPrompt(for: .camera))

        mocks.camera.status = .notDetermined
        XCTAssertFalse(routing.needsSettingsPrompt(for: .camera))
    }

    func testOpenSettingsIfDenied() {
        let settingsURL = URL(string: "app-settings://")
        let (manager, mocks) = TestFixtures.makeManager(settingsURL: settingsURL)
        let router = MockSettingsRouter()
        let routing = PermissionRouting(manager: manager, router: router)
        mocks.notifications.status = .denied

        XCTAssertTrue(routing.openSettingsIfDenied(.notifications))
        XCTAssertEqual(router.openedURL, settingsURL)
    }

    func testPermissionTypeDisplayMetadata() {
        for type in PermissionType.allCases {
            XCTAssertFalse(type.settingsTitle.isEmpty)
            XCTAssertFalse(type.settingsMessage.isEmpty)
            XCTAssertFalse(type.systemImageName.isEmpty)
        }
    }
}
