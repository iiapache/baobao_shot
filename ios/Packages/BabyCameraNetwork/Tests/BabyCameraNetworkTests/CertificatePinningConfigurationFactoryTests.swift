import XCTest
@testable import BabyCameraNetwork

final class CertificatePinningConfigurationFactoryTests: XCTestCase {
    func testForceStubUsesDisabledConfiguration() {
        let config = CertificatePinningConfigurationFactory.resolve(forceStub: true)
        XCTAssertFalse(config.isEnabled)
        XCTAssertTrue(config.pinnedHashesByHost.isEmpty)
    }

    func testFeatureFlagDisabledOverridesInfoPlist() {
        let config = CertificatePinningConfigurationFactory.resolve(
            infoDictionary: [
                CertificatePinningConfigurationFactory.infoPlistEnabledKey: "YES",
                "CertificatePinHashesAPICN": "pin-a",
            ],
            featureFlagEnabled: false
        )
        XCTAssertFalse(config.isEnabled)
    }

    func testFeatureFlagEnabledOverridesInfoPlistOff() {
        let config = CertificatePinningConfigurationFactory.resolve(
            infoDictionary: [
                CertificatePinningConfigurationFactory.infoPlistEnabledKey: "NO",
                "CertificatePinHashesAPICN": "pin-a",
            ],
            featureFlagEnabled: true
        )
        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.pinnedHashes(for: "api-cn.babygrowth.app"), ["pin-a"])
    }

    func testReadsEnabledAndHashesFromInfoPlist() {
        let config = CertificatePinningConfigurationFactory.resolve(
            infoDictionary: [
                CertificatePinningConfigurationFactory.infoPlistEnabledKey: "YES",
                "CertificatePinHashesAPICN": "pin-a,pin-b",
                "CertificatePinHashesAPIOS": "pin-os",
            ]
        )
        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.pinnedHashes(for: "api-cn.babygrowth.app"), ["pin-a", "pin-b"])
        XCTAssertEqual(config.pinnedHashes(for: "api-os.babygrowth.app"), ["pin-os"])
    }

    func testIgnoresUnexpandedBuildSettingPlaceholders() {
        let config = CertificatePinningConfigurationFactory.resolve(
            infoDictionary: [
                CertificatePinningConfigurationFactory.infoPlistEnabledKey: "$(CERT_PINNING_ENABLED)",
                "CertificatePinHashesAPICN": "$(CERT_PIN_HASHES_API_CN)",
            ]
        )
        XCTAssertFalse(config.isEnabled)
    }

    func testNetworkSessionFactoryForceStubHasNoDelegate() {
        let session = NetworkSessionFactory.makeSession(forceStub: true)
        XCTAssertNil(session.delegate)
    }

    func testNetworkSessionFactoryEnabledAttachesDelegate() {
        let session = NetworkSessionFactory.makeSession(
            infoDictionary: [
                CertificatePinningConfigurationFactory.infoPlistEnabledKey: "YES",
                "CertificatePinHashesAPICN": "stub-pin",
            ]
        )
        XCTAssertNotNil(session.delegate)
        XCTAssertTrue(session.delegate is CertificatePinningDelegate)
    }

    func testParseBooleanPlistValue() {
        XCTAssertTrue(CertificatePinningConfigurationFactory.parseBooleanPlistValue("YES"))
        XCTAssertTrue(CertificatePinningConfigurationFactory.parseBooleanPlistValue("true"))
        XCTAssertFalse(CertificatePinningConfigurationFactory.parseBooleanPlistValue("NO"))
        XCTAssertFalse(CertificatePinningConfigurationFactory.parseBooleanPlistValue("$(CERT_PINNING_ENABLED)"))
    }

    func testParseHashList() {
        XCTAssertEqual(
            CertificatePinningConfigurationFactory.parseHashList("a, b ,c"),
            ["a", "b", "c"]
        )
        XCTAssertTrue(CertificatePinningConfigurationFactory.parseHashList("$(CERT_PIN_HASHES_API_CN)").isEmpty)
    }
}

private extension NetworkSessionFactory {
    static func makeSession(
        infoDictionary: [String: Any],
        forceStub: Bool = false,
        featureFlagEnabled: Bool? = nil
    ) -> URLSession {
        let pinning = CertificatePinningConfigurationFactory.resolve(
            forceStub: forceStub,
            featureFlagEnabled: featureFlagEnabled,
            infoDictionary: infoDictionary
        )
        return CertificatePinningSessionFactory.makeSession(configuration: pinning)
    }
}
