import Security
import XCTest
@testable import BabyCameraNetwork

final class CertificatePinningTests: XCTestCase {
    func testDefaultConfigurationIsDisabled() {
        XCTAssertFalse(CertificatePinningConfiguration.default.isEnabled)
    }

    func testDisabledFactoryUsesPlainSession() {
        let session = CertificatePinningSessionFactory.makeSession(
            configuration: .default
        )
        XCTAssertNil(session.delegate)
    }

    func testForceStubPathUsesPlainSession() {
        let session = NetworkSessionFactory.makeSession(forceStub: true)
        XCTAssertNil(session.delegate)
    }

    func testEnabledFactoryAttachesDelegate() {
        let config = CertificatePinningConfiguration(
            isEnabled: true,
            pinnedHashesByHost: ["api-cn.babygrowth.app": ["stub-pin-hash"]]
        )
        let session = CertificatePinningSessionFactory.makeSession(configuration: config)
        XCTAssertNotNil(session.delegate)
        XCTAssertTrue(session.delegate is CertificatePinningDelegate)
    }

    func testPinnedHashesLookupByHost() {
        let config = CertificatePinningConfiguration(
            isEnabled: true,
            pinnedHashesByHost: [
                "api-cn.babygrowth.app": ["pin-a"],
                "api-os.babygrowth.app": ["pin-b"],
            ]
        )
        XCTAssertEqual(config.pinnedHashes(for: "api-cn.babygrowth.app"), ["pin-a"])
        XCTAssertEqual(config.pinnedHashes(for: "unknown.host"), [])
    }

    func testRSASPkiPrefixLength() {
        XCTAssertEqual(CertificatePinningValidator.spkiPrefix(forKeyType: kSecAttrKeyTypeRSA as String, keySizeInBits: 2_048)?.count, 24)
    }

    func testECP256SpkiPrefixLength() {
        XCTAssertEqual(
            CertificatePinningValidator.spkiPrefix(forKeyType: kSecAttrKeyTypeECSECPrimeRandom as String, keySizeInBits: 256)?.count,
            26
        )
    }
}
