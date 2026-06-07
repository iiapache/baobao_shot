import BabyCameraNetwork
import XCTest
@testable import BabyCameraBaby

@MainActor
final class BabyListViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testLoadPopulatesStore() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test001/babies" {
                return MockResponse(
                    statusCode: 200,
                    json: MockServer.babyListSuccessJSON(babyId: "bb_list", name: "列表宝")
                )
            }
            return nil
        }

        let store = CurrentBabyEnvironment(restorePersistedSelection: false)
        let viewModel = BabyListViewModel(
            service: BabyService(
                familyId: "fam_test001",
                client: makeAuthenticatedClient(session: MockURLProtocol.makeSession())
            ),
            currentBabyStore: store
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.babies.count, 1)
        XCTAssertEqual(viewModel.babies[0].name, "列表宝")
        XCTAssertEqual(store.currentBabyId, "bb_list")
    }

    func testSelectBabyUpdatesStore() {
        let store = CurrentBabyEnvironment(restorePersistedSelection: false)
        store.replaceBabies([
            BabyProfile(id: "bb_a", familyId: "fam", name: "A", birthDate: "2024-01-01"),
            BabyProfile(id: "bb_b", familyId: "fam", name: "B", birthDate: "2024-02-01"),
        ])

        let viewModel = BabyListViewModel(
            service: BabyService(
                familyId: "fam",
                client: makeAuthenticatedClient(session: MockURLProtocol.makeSession())
            ),
            currentBabyStore: store
        )

        viewModel.selectBaby(id: "bb_b")
        XCTAssertEqual(store.currentBabyId, "bb_b")
    }
}
