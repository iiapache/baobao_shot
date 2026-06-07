import BabyCameraNetwork
import XCTest
@testable import BabyCameraOnboarding

final class ConsentVersionCheckerTests: XCTestCase {
    private let userId = "usr_consent_checker_test"

    override func setUp() {
        super.setUp()
        ConsentVersionChecker.clearAgreedVersion(for: userId)
    }

    override func tearDown() {
        ConsentVersionChecker.clearAgreedVersion(for: userId)
        super.tearDown()
    }

    func testRequiresReconsentWithoutServerConsent() {
        let profile = makeProfile(childData: false)
        XCTAssertTrue(ConsentVersionChecker.requiresReconsent(userId: userId, profile: profile))
    }

    func testRequiresReconsentWhenLocalVersionMissing() {
        let profile = makeProfile(childData: true)
        XCTAssertTrue(ConsentVersionChecker.requiresReconsent(userId: userId, profile: profile))
    }

    func testRequiresReconsentWhenLocalVersionStale() {
        let profile = makeProfile(childData: true)
        ConsentVersionChecker.recordAgreedVersion("child_consent_v0", userId: userId)
        XCTAssertTrue(ConsentVersionChecker.requiresReconsent(userId: userId, profile: profile))
    }

    func testValidConsentWhenVersionsMatch() {
        let profile = makeProfile(childData: true)
        ConsentVersionChecker.recordAgreedVersion(ChildDataConsent.currentVersion, userId: userId)
        XCTAssertTrue(ConsentVersionChecker.hasValidConsent(userId: userId, profile: profile))
        XCTAssertFalse(ConsentVersionChecker.requiresReconsent(userId: userId, profile: profile))
    }

    func testGateBlocksCameraWhenVersionStale() {
        let profile = makeProfile(childData: true)
        ConsentVersionChecker.recordAgreedVersion("child_consent_v0", userId: userId)
        XCTAssertFalse(ChildDataConsentGate.isFeatureAllowed(.camera, profile: profile, userId: userId))
    }

    func testGateAllowsCameraWhenVersionMatches() {
        let profile = makeProfile(childData: true)
        ConsentVersionChecker.recordAgreedVersion(ChildDataConsent.currentVersion, userId: userId)
        XCTAssertTrue(ChildDataConsentGate.isFeatureAllowed(.camera, profile: profile, userId: userId))
    }

    func testCurrentVersionMatchesBackend() {
        XCTAssertEqual(ConsentVersionChecker.currentVersion, "child_consent_v1")
    }

    private func makeProfile(childData: Bool) -> UserProfile {
        UserProfile(
            nickname: "测试",
            avatarUrl: nil,
            region: "cn",
            consents: UserConsents(childData: childData)
        )
    }
}
