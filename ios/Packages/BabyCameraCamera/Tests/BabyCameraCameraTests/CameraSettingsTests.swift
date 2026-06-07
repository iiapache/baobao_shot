import XCTest
@testable import BabyCameraCamera

@MainActor
final class CameraSettingsTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: CameraSettingsStore.burnInWatermarkDefaultsKey)
        super.tearDown()
    }

    func testDefaultBurnInWatermarkIsFalse() {
        let settings = CameraSettings.default
        XCTAssertFalse(settings.burnInWatermark)
    }

    func testSettingsStoreDefaultsToFalseWhenUnset() {
        let store = CameraSettingsStore(restorePersisted: true)
        XCTAssertFalse(store.burnInWatermark)
        XCTAssertFalse(store.settings.burnInWatermark)
    }

    func testSettingsStorePersistsBurnInWatermarkToggle() {
        let store = CameraSettingsStore(restorePersisted: false)
        store.burnInWatermark = true

        let restored = CameraSettingsStore(restorePersisted: true)
        XCTAssertTrue(restored.burnInWatermark)
    }

    func testSettingsCodableRoundTrip() throws {
        let original = CameraSettings(burnInWatermark: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CameraSettings.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCameraStateOverlayInfo() {
        let state = CameraState()
        let info = CameraOverlayInfo(
            babyId: "bb_1",
            babyName: "豆豆",
            birthDate: "2024-01-15",
            displayAge: "出生第 6 天",
            ageDay: 6
        )

        state.setOverlayInfo(info)
        XCTAssertEqual(state.viewState.overlayInfo, info)

        state.setOverlayInfo(nil)
        XCTAssertNil(state.viewState.overlayInfo)
    }
}
