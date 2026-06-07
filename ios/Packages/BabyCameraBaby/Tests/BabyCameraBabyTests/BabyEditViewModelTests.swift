import BabyCameraNetwork
import XCTest
@testable import BabyCameraBaby

@MainActor
final class BabyEditViewModelTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeViewModel(
        mode: BabyEditViewModel.Mode,
        store: CurrentBabyEnvironment = CurrentBabyEnvironment(restorePersistedSelection: false)
    ) -> BabyEditViewModel {
        BabyEditViewModel(
            mode: mode,
            service: BabyService(
                familyId: "fam_test001",
                client: makeAuthenticatedClient(session: MockURLProtocol.makeSession())
            ),
            currentBabyStore: store
        )
    }

    func testValidationRequiresNameAndBirthDate() {
        let viewModel = makeViewModel(mode: .create)
        viewModel.name = "   "

        XCTAssertFalse(viewModel.validateForm())
        XCTAssertEqual(viewModel.validationMessage, BabyFormValidation.nameRequiredMessage)
    }

    func testCreateBabySuccess() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/families/fam_test001/babies" {
                return MockResponse(statusCode: 200, json: MockServer.babySuccessJSON(babyId: "bb_new"))
            }
            return nil
        }

        let store = CurrentBabyEnvironment(restorePersistedSelection: false)
        let viewModel = makeViewModel(mode: .create, store: store)
        viewModel.name = "糖糖"
        viewModel.gender = .female

        let saved = await viewModel.save()
        XCTAssertEqual(saved?.id, "bb_new")
        XCTAssertEqual(store.currentBabyId, "bb_new")
        XCTAssertEqual(store.babies.count, 1)
    }

    func testUpdateBabySuccess() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/babies/bb_edit" {
                return MockResponse(statusCode: 200, json: MockServer.babySuccessJSON(babyId: "bb_edit", name: "新名"))
            }
            return nil
        }

        let existing = BabyProfile(
            id: "bb_edit",
            familyId: "fam_test001",
            name: "旧名",
            birthDate: "2024-01-01"
        )
        let viewModel = makeViewModel(mode: .edit(existing))
        viewModel.name = "新名"

        let saved = await viewModel.save()
        XCTAssertEqual(saved?.name, "新名")
    }

    func testDeleteBabyRemovesFromStore() async throws {
        MockURLProtocol.register { request in
            if request.url?.path == "/v1/babies/bb_delete" {
                return MockResponse(statusCode: 200, json: MockServer.babyDeleteSuccessJSON(babyId: "bb_delete"))
            }
            return nil
        }

        let store = CurrentBabyEnvironment(restorePersistedSelection: false)
        store.replaceBabies([
            BabyProfile(id: "bb_delete", familyId: "fam_test001", name: "待删", birthDate: "2024-01-01"),
        ])
        store.select(babyId: "bb_delete")

        let viewModel = makeViewModel(
            mode: .edit(BabyProfile(id: "bb_delete", familyId: "fam_test001", name: "待删", birthDate: "2024-01-01")),
            store: store
        )

        let deleted = await viewModel.delete()
        XCTAssertTrue(deleted)
        XCTAssertTrue(store.babies.isEmpty)
        XCTAssertNil(store.currentBabyId)
    }

    func testUploadAvatarRequiresSavedProfile() async {
        let viewModel = makeViewModel(mode: .create)
        await viewModel.uploadAvatar(imageData: Data("jpeg".utf8))
        XCTAssertEqual(viewModel.validationMessage, "请先保存宝宝档案后再上传头像")
    }
}
