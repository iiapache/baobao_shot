import XCTest
@testable import BabyCameraFamily

final class InvitationCodeServiceTests: XCTestCase {
    private let service = InvitationCodeService(signingSecret: "secret-key")

    func testSignInviteCodeMatchesBackendFormat() {
        let sig = InvitationCodeService.signInviteCode("123456", signingSecret: "secret-key")
        XCTAssertEqual(sig, "419ae45f96afc274e3d804e4e905e4e35d727d622580602a5fc05b641ce1e5b6")
    }

    func testVerifyValidPayload() throws {
        let payload = InviteQRPayload(
            scheme: "baobao://invite",
            code: "123456",
            sig: InvitationCodeService.signInviteCode("123456", signingSecret: "secret-key")
        )
        XCTAssertTrue(service.verifyPayload(payload))
    }

    func testVerifyRejectsWrongSecret() {
        let payload = InviteQRPayload(
            scheme: "baobao://invite",
            code: "123456",
            sig: InvitationCodeService.signInviteCode("123456", signingSecret: "secret-key")
        )
        let wrongService = InvitationCodeService(signingSecret: "wrong-key")
        XCTAssertFalse(wrongService.verifyPayload(payload))
    }

    func testDecodeJSONPayload() throws {
        let sig = InvitationCodeService.signInviteCode("654321", signingSecret: "secret-key")
        let json = """
        {"scheme":"baobao://invite","code":"654321","sig":"\(sig)"}
        """
        let payload = try service.decodePayload(from: json)
        XCTAssertEqual(payload.code, "654321")
        XCTAssertEqual(payload.scheme, "baobao://invite")
    }

    func testDecodePlainSixDigitCode() throws {
        let payload = try service.decodePayload(from: "123456")
        XCTAssertEqual(payload.code, "123456")
    }

    func testGenerateQRImage() throws {
        let payload = InviteQRPayload(
            scheme: "baobao://invite",
            code: "123456",
            sig: InvitationCodeService.signInviteCode("123456", signingSecret: "secret-key")
        )
        let image = try service.generateQRImage(from: payload)
        XCTAssertGreaterThan(image.size.width, 0)
    }

    func testEncodePayloadRoundTrip() throws {
        let payload = InviteQRPayload(
            scheme: "baobao://invite",
            code: "111222",
            sig: InvitationCodeService.signInviteCode("111222", signingSecret: "secret-key")
        )
        let json = try service.encodePayload(payload)
        let decoded = try service.decodePayload(from: json)
        XCTAssertEqual(decoded, payload)
    }
}
