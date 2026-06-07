import BabyCameraNetwork
import XCTest
@testable import BabyCameraFamily

@MainActor
final class JoinFamilyViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeViewModel() -> JoinFamilyViewModel {
        let service = FamilyService(
            configuration: FamilyServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: InMemoryTokenStore(access: "access", refresh: "refresh"),
                session: MockURLProtocol.makeSession(),
                inviteSigningSecret: "test-secret"
            )
        )
        return JoinFamilyViewModel(familyService: service)
    }

    func testJoinWithManualCode() async {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/invitations/123456/join" {
                return MockResponse(statusCode: 200, json: MockServer.joinFamilyJSON())
            }
            return nil
        }

        let viewModel = makeViewModel()
        viewModel.inviteCode = "123456"
        viewModel.selectedRelation = .grandma
        viewModel.nickname = "外婆"

        let result = await viewModel.join()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.familyId, "fam_test_001")
    }

    func testHandleScannedContentExtractsCode() {
        let sig = InvitationCodeService.signInviteCode("888888", signingSecret: "test-secret")
        let viewModel = makeViewModel()
        viewModel.handleScannedContent("""
        {"scheme":"baobao://invite","code":"888888","sig":"\(sig)"}
        """)
        XCTAssertEqual(viewModel.inviteCode, "888888")
    }

    func testCannotSubmitWithoutCode() async {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.canSubmit)
        let result = await viewModel.join()
        XCTAssertNil(result)
    }
}

@MainActor
final class FamilyMembersViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testLoadMembers() async {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001" {
                return MockResponse(statusCode: 200, json: MockServer.familyDetailJSON())
            }
            return nil
        }

        let service = FamilyService(
            configuration: FamilyServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: InMemoryTokenStore(access: "access", refresh: "refresh"),
                session: MockURLProtocol.makeSession()
            )
        )
        let viewModel = FamilyMembersViewModel(familyId: "fam_test_001", familyService: service)

        await viewModel.load()

        XCTAssertEqual(viewModel.members.count, 2)
        XCTAssertEqual(viewModel.familyName, "豆豆的家")
        XCTAssertTrue(viewModel.isAdmin)
        XCTAssertTrue(viewModel.canInvite)
    }

    func testTransferCandidatesExcludeAdminAndGuest() async {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001" {
                return MockResponse(statusCode: 200, json: MockServer.familyDetailJSON())
            }
            return nil
        }

        let service = FamilyService(
            configuration: FamilyServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: InMemoryTokenStore(access: "access", refresh: "refresh"),
                session: MockURLProtocol.makeSession()
            )
        )
        let viewModel = FamilyMembersViewModel(familyId: "fam_test_001", familyService: service)
        await viewModel.load()

        XCTAssertEqual(viewModel.transferCandidates.count, 1)
        XCTAssertEqual(viewModel.transferCandidates[0].id, "usr_member")
    }
}
