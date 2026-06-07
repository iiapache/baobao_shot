import BabyCameraNetwork
import XCTest
@testable import BabyCameraFamily

final class FamilyServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeFamilyService(tokenStore: TokenStore = InMemoryTokenStore(access: "access", refresh: "refresh")) -> FamilyService {
        FamilyService(
            configuration: FamilyServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: tokenStore,
                session: MockURLProtocol.makeSession(),
                inviteSigningSecret: "test-secret"
            )
        )
    }

    func testListFamilies() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families", request.httpMethod == "GET" {
                return MockResponse(statusCode: 200, json: MockServer.familyListJSON())
            }
            return nil
        }

        let service = makeFamilyService()
        let families = try await service.listFamilies()
        XCTAssertEqual(families.count, 1)
        XCTAssertEqual(families[0].id, "fam_test_001")
        XCTAssertEqual(families[0].role, .admin)
    }

    func testCreateFamily() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families", request.httpMethod == "POST" {
                return MockResponse(statusCode: 200, json: MockServer.createFamilyJSON(name: "测试家"))
            }
            return nil
        }

        let service = makeFamilyService()
        let family = try await service.createFamily(name: "测试家")
        XCTAssertEqual(family.name, "测试家")
        XCTAssertEqual(family.role, .admin)
    }

    func testGetFamilyDetail() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001" {
                return MockResponse(statusCode: 200, json: MockServer.familyDetailJSON())
            }
            return nil
        }

        let service = makeFamilyService()
        let detail = try await service.getFamily(familyId: "fam_test_001")
        XCTAssertEqual(detail.members.count, 2)
        XCTAssertEqual(detail.members[0].nickname, "豆豆妈")
    }

    func testCreateInvitationAndJoin() async throws {
        let sig = InvitationCodeService.signInviteCode("123456", signingSecret: "test-secret")

        MockURLProtocol.register { request in
            let path = request.url?.path ?? ""
            if path == "/v1/families/fam_test_001/invitations", request.httpMethod == "POST" {
                return MockResponse(statusCode: 200, json: MockServer.invitationJSON(code: "123456", sig: sig))
            }
            if path == "/v1/invitations/123456/join", request.httpMethod == "POST" {
                return MockResponse(statusCode: 200, json: MockServer.joinFamilyJSON())
            }
            return nil
        }

        let service = makeFamilyService()
        let invitation = try await service.createInvitation(familyId: "fam_test_001")
        XCTAssertEqual(invitation.code, "123456")
        XCTAssertTrue(service.invitationCodeService.verifyPayload(invitation.qrPayload))

        let result = try await service.joinFamily(code: "123456", relation: .grandma, nickname: "外婆")
        XCTAssertEqual(result.familyId, "fam_test_001")
        XCTAssertEqual(result.role, .family)
    }

    func testJoinFromScannedQR() async throws {
        let sig = InvitationCodeService.signInviteCode("654321", signingSecret: "test-secret")
        let json = """
        {"scheme":"baobao://invite","code":"654321","sig":"\(sig)"}
        """

        MockURLProtocol.register { request in
            if request.url?.path == "/v1/invitations/654321/join" {
                return MockResponse(statusCode: 200, json: MockServer.joinFamilyJSON(familyId: "fam_scanned"))
            }
            return nil
        }

        let service = makeFamilyService()
        let result = try await service.joinFamily(fromScannedContent: json, relation: .mom, nickname: nil)
        XCTAssertEqual(result.familyId, "fam_scanned")
    }

    func testNotAuthenticatedThrows() async {
        let service = makeFamilyService(tokenStore: InMemoryTokenStore())

        do {
            _ = try await service.listFamilies()
            XCTFail("expected not authenticated")
        } catch let error as FamilyServiceError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testTransferAdmin() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001/transfer" {
                return MockResponse(statusCode: 200, json: MockServer.transferAdminJSON())
            }
            return nil
        }

        let service = makeFamilyService()
        let result = try await service.transferAdmin(familyId: "fam_test_001", targetUserId: "usr_member")
        XCTAssertEqual(result.newAdminUserId, "usr_member")
    }

    func testTakeover() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001/takeover" {
                return MockResponse(statusCode: 200, json: MockServer.takeoverVoteJSON())
            }
            return nil
        }

        let service = makeFamilyService()
        let result = try await service.takeover(familyId: "fam_test_001", choice: .approve)
        XCTAssertEqual(result.voteId, "tov_test_001")
        XCTAssertEqual(result.status, .voting)
    }
}
