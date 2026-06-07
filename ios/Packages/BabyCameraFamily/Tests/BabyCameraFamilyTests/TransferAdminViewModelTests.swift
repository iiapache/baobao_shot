import BabyCameraNetwork
import XCTest
@testable import BabyCameraFamily

@MainActor
final class TransferAdminViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeService() -> FamilyService {
        FamilyService(
            configuration: FamilyServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: InMemoryTokenStore(access: "access", refresh: "refresh"),
                session: MockURLProtocol.makeSession()
            )
        )
    }

    private func makeViewModel(service: FamilyService? = nil) -> TransferAdminViewModel {
        TransferAdminViewModel(
            familyId: "fam_test_001",
            familyName: "豆豆的家",
            candidates: [
                FamilyMember(id: "usr_member", role: .family, nickname: "外婆", joinedAt: "")
            ],
            familyService: service ?? makeService()
        )
    }

    func testSelectTargetStaysIdle() {
        let viewModel = makeViewModel()
        let member = viewModel.candidates[0]

        viewModel.selectTarget(member)

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.targetMember?.id, "usr_member")
        XCTAssertTrue(viewModel.canProceed)
    }

    func testConfirmationFlowTransitions() {
        let viewModel = makeViewModel()
        viewModel.selectTarget(viewModel.candidates[0])

        viewModel.requestConfirmation()
        XCTAssertEqual(viewModel.state, .confirming)

        viewModel.cancelConfirmation()
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testTransferSuccessStateMachine() async {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001/transfer" {
                return MockResponse(statusCode: 200, json: MockServer.transferAdminJSON())
            }
            return nil
        }

        let viewModel = makeViewModel()
        viewModel.selectTarget(viewModel.candidates[0])
        viewModel.requestConfirmation()

        await viewModel.confirmTransfer()

        XCTAssertEqual(viewModel.state, .success)
        XCTAssertEqual(viewModel.result?.newAdminUserId, "usr_member")
    }

    func testTransferErrorStateMachine() async {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001/transfer" {
                return MockResponse(
                    statusCode: 422,
                    json: """
                    {
                      "code": "FAMILY_TRANSFER_TARGET_INVALID",
                      "message": "invalid transfer target",
                      "requestId": "req_transfer_err"
                    }
                    """
                )
            }
            return nil
        }

        let viewModel = makeViewModel()
        viewModel.selectTarget(viewModel.candidates[0])
        viewModel.requestConfirmation()

        await viewModel.confirmTransfer()

        XCTAssertEqual(viewModel.state, .error("无法转让给该成员，请选择其他家人"))
        viewModel.clearError()
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testSubmittingStateDuringTransfer() async {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001/transfer" {
                try? await Task.sleep(nanoseconds: 50_000_000)
                return MockResponse(statusCode: 200, json: MockServer.transferAdminJSON())
            }
            return nil
        }

        let viewModel = makeViewModel()
        viewModel.selectTarget(viewModel.candidates[0])
        viewModel.requestConfirmation()

        let task = Task { await viewModel.confirmTransfer() }
        try? await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(viewModel.state, .submitting)
        await task.value
        XCTAssertEqual(viewModel.state, .success)
    }
}

@MainActor
final class TakeoverViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeService() -> FamilyService {
        FamilyService(
            configuration: FamilyServiceConfiguration(
                region: .cn,
                regionConfig: RegionConfig(region: .cn, appVersion: "1.0.0", deviceId: "test-device"),
                tokenStore: InMemoryTokenStore(access: "access", refresh: "refresh"),
                session: MockURLProtocol.makeSession()
            )
        )
    }

    private func makeViewModel(isAdmin: Bool = false) -> TakeoverViewModel {
        TakeoverViewModel(
            familyId: "fam_test_001",
            familyName: "豆豆的家",
            isAdmin: isAdmin,
            currentRole: isAdmin ? .admin : .family,
            familyService: makeService()
        )
    }

    func testInitiateConfirmationTransitions() {
        let viewModel = makeViewModel()

        viewModel.requestInitiateConfirmation()
        XCTAssertEqual(viewModel.state, .confirming)

        viewModel.cancelConfirmation()
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testInitiateTakeoverSuccess() async {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001/takeover" {
                return MockResponse(statusCode: 200, json: MockServer.takeoverVoteJSON())
            }
            return nil
        }

        let viewModel = makeViewModel()
        viewModel.requestInitiateConfirmation()
        await viewModel.confirmInitiate()

        XCTAssertNotNil(viewModel.vote)
        XCTAssertEqual(viewModel.vote?.status, .voting)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testVoteApproveEntersObjectionPeriod() async {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001/takeover" {
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.takeoverVoteJSON(
                        status: "objection_period",
                        approveCount: 2,
                        objectionEndsAt: "2026-06-13T10:00:00Z"
                    )
                )
            }
            return nil
        }

        let viewModel = makeViewModel()
        viewModel.replaceVote(
            TakeoverVoteResult(
                voteId: "tov_test_001",
                status: .voting,
                initiatorUserId: "usr_other",
                eligibleVoters: 3,
                approveCount: 1,
                rejectCount: 0,
                requiredApprovals: 2
            )
        )

        await viewModel.vote(approve: true)

        XCTAssertEqual(viewModel.vote?.status, .objectionPeriod)
        XCTAssertEqual(viewModel.state, .success)
    }

    func testTakeoverErrorForActiveAdmin() async {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001/takeover" {
                return MockResponse(
                    statusCode: 422,
                    json: """
                    {
                      "code": "FAMILY_ADMIN_ACTIVE",
                      "message": "admin is still active",
                      "requestId": "req_takeover_err"
                    }
                    """
                )
            }
            return nil
        }

        let viewModel = makeViewModel()
        viewModel.requestInitiateConfirmation()
        await viewModel.confirmInitiate()

        XCTAssertEqual(viewModel.state, .error("管理员近期仍活跃，暂不可发起接管"))
    }

    func testAdminCancelObjectionSuccess() async {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test_001/takeover" {
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.takeoverVoteJSON(status: "cancelled")
                )
            }
            return nil
        }

        let viewModel = makeViewModel(isAdmin: true)
        viewModel.replaceVote(
            TakeoverVoteResult(
                voteId: "tov_test_001",
                status: .objectionPeriod,
                initiatorUserId: "usr_member",
                eligibleVoters: 3,
                approveCount: 2,
                rejectCount: 0,
                requiredApprovals: 2,
                objectionEndsAt: "2026-06-13T10:00:00Z"
            )
        )

        await viewModel.cancelObjection()

        XCTAssertEqual(viewModel.vote?.status, .cancelled)
        XCTAssertEqual(viewModel.state, .success)
    }
}
