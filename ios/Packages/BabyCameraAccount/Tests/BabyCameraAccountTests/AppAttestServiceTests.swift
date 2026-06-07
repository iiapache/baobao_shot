import XCTest
@testable import BabyCameraAccount

final class AppAttestServiceTests: XCTestCase {
    func testDisabledServiceIsNotSupported() {
        let service = AppAttestService(isEnabled: false)
        XCTAssertFalse(service.isSupported)
    }

    func testDisabledGenerateKeyThrows() async {
        let service = AppAttestService(isEnabled: false)
        do {
            _ = try await service.generateKey()
            XCTFail("expected disabled error")
        } catch let error as AppAttestError {
            XCTAssertEqual(error, .disabled)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDisabledAttestKeyThrows() async {
        let service = AppAttestService(isEnabled: false)
        do {
            _ = try await service.attestKey("key-id", clientDataHash: Data())
            XCTFail("expected disabled error")
        } catch let error as AppAttestError {
            XCTAssertEqual(error, .disabled)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDisabledGenerateAssertionThrows() async {
        let service = AppAttestService(isEnabled: false)
        do {
            _ = try await service.generateAssertion(keyId: "key-id", clientDataHash: Data())
            XCTFail("expected disabled error")
        } catch let error as AppAttestError {
            XCTAssertEqual(error, .disabled)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
