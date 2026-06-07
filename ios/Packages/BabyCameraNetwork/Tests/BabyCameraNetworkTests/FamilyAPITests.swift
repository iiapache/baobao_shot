import XCTest
@testable import BabyCameraNetwork

final class FamilyAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testListFamilies() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/families")
            return MockResponse(statusCode: 200, json: MockServer.familyListJSON())
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = FamilyAPI(client: client)
        let result = try await api.listFamilies()
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].familyId, "fam_test_001")
    }

    func testJoinFamilySendsRelation() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.url?.path, "/v1/invitations/123456/join")
            XCTAssertEqual(request.httpMethod, "POST")
            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["relation"] as? String, "grandma")
                XCTAssertEqual(json["nickname"] as? String, "外婆")
            } else {
                XCTFail("missing body")
            }
            return MockResponse(statusCode: 200, json: MockServer.joinFamilyJSON())
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = FamilyAPI(client: client)
        let result = try await api.joinFamily(code: "123456", relation: "grandma", nickname: "外婆")
        XCTAssertEqual(result.familyId, "fam_test_001")
        XCTAssertEqual(result.role, "family")
    }

    func testCreateInvitation() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.url?.path, "/v1/families/fam_001/invitations")
            return MockResponse(statusCode: 200, json: MockServer.invitationJSON())
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = FamilyAPI(client: client)
        let result = try await api.createInvitation(familyId: "fam_001")
        XCTAssertEqual(result.code, "123456")
        XCTAssertEqual(result.qrPayload.scheme, "baobao://invite")
    }

    func testTransferAdminSendsTargetUserId() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.url?.path, "/v1/families/fam_001/transfer")
            XCTAssertEqual(request.httpMethod, "POST")
            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["targetUserId"] as? String, "usr_target")
            } else {
                XCTFail("missing body")
            }
            return MockResponse(statusCode: 200, json: MockServer.transferAdminJSON(familyId: "fam_001"))
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = FamilyAPI(client: client)
        let result = try await api.transferAdmin(familyId: "fam_001", targetUserId: "usr_target")
        XCTAssertEqual(result.newAdminUserId, "usr_member")
    }

    func testTakeoverVoteSendsChoice() async throws {
        MockURLProtocol.register { request in
            XCTAssertEqual(request.url?.path, "/v1/families/fam_001/takeover")
            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["choice"] as? String, "approve")
            } else {
                XCTFail("missing body")
            }
            return MockResponse(statusCode: 200, json: MockServer.takeoverVoteJSON())
        }

        let client = makeAuthenticatedClient(session: MockURLProtocol.makeSession())
        let api = FamilyAPI(client: client)
        let result = try await api.takeover(familyId: "fam_001", choice: "approve")
        XCTAssertEqual(result.status, "voting")
    }
}
