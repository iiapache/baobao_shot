import XCTest
@testable import BabyCameraAccount

final class AppAttestConfigurationFactoryTests: XCTestCase {
    func testForceStubReturnsDisabledService() {
        let service = AppAttestConfigurationFactory.resolve(forceStub: true)
        XCTAssertFalse(service.isSupported)
    }

    func testResolveEnabledFromPlistYes() {
        XCTAssertTrue(
            AppAttestConfigurationFactory.resolveEnabled(
                from: [AppAttestConfigurationFactory.infoPlistEnabledKey: "YES"]
            )
        )
    }

    func testResolveEnabledFromUnresolvedPlaceholder() {
        XCTAssertFalse(
            AppAttestConfigurationFactory.resolveEnabled(
                from: [AppAttestConfigurationFactory.infoPlistEnabledKey: "$(APP_ATTEST_ENABLED)"]
            )
        )
    }

    func testStubServiceThrowsDisabled() async {
        let service = StubAppAttestService()
        do {
            _ = try await service.generateKey()
            XCTFail("expected disabled")
        } catch let error as AppAttestError {
            XCTAssertEqual(error, .disabled)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testClientDataHashIsDeterministic() {
        let hash = AppAttestIAPAttachmentBuilder.clientDataHash(
            transactionId: "tx-1",
            productId: "credits_100"
        )
        XCTAssertEqual(hash.count, 32)
        XCTAssertEqual(
            hash,
            AppAttestIAPAttachmentBuilder.clientDataHash(
                transactionId: "tx-1",
                productId: "credits_100"
            )
        )
    }
}
