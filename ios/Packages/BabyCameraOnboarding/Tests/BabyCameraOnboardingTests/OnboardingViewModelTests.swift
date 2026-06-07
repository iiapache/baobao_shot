import BabyCameraAccount
import BabyCameraBaby
import BabyCameraFamily
import BabyCameraNetwork
import DesignSystem
import XCTest
@testable import BabyCameraOnboarding

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    override func tearDown() {
        ConsentVersionChecker.clearAgreedVersion(for: "usr_test_001")
        super.tearDown()
    }

    private func makeSession(isNewUser: Bool = true) -> AuthSession {
        AuthSession(
            userId: "usr_test_001",
            isNewUser: isNewUser,
            profile: UserProfile(
                nickname: nil,
                avatarUrl: nil,
                region: "cn",
                consents: UserConsents(childData: false)
            )
        )
    }

    private func makeViewModel(
        service: MockOnboardingService = MockOnboardingService(),
        progressStore: InMemoryOnboardingProgressStore = InMemoryOnboardingProgressStore()
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            session: makeSession(),
            service: service,
            progressStore: progressStore,
            currentBabyStore: CurrentBabyEnvironment(restorePersistedSelection: false)
        )
    }

    func testInitialStepIsProfile() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.currentStep, .profile)
    }

    func testProfileStepRequiresNickname() async {
        let viewModel = makeViewModel()
        viewModel.nickname = "   "

        let success = await viewModel.proceed()
        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.currentStep, .profile)
        XCTAssertEqual(viewModel.validationMessage, L10n.string("onboarding.validation.nickname_required"))
    }

    func testProfileStepAdvancesOnSuccess() async {
        let service = MockOnboardingService()
        let viewModel = makeViewModel(service: service)
        viewModel.nickname = "豆豆妈"

        let success = await viewModel.proceed()
        XCTAssertTrue(success)
        XCTAssertEqual(viewModel.currentStep, .family)
        XCTAssertEqual(service.updateProfileCalls, ["豆豆妈"])
    }

    func testCreateFamilyPathDefersAPICallUntilConsent() async {
        let service = MockOnboardingService()
        let viewModel = makeViewModel(service: service)
        viewModel.nickname = "豆豆妈"
        _ = await viewModel.proceed()

        viewModel.familyPath = .create
        viewModel.familyName = "豆豆的家"
        let familySuccess = await viewModel.proceed()
        XCTAssertTrue(familySuccess)
        XCTAssertEqual(viewModel.currentStep, .baby)
        XCTAssertTrue(service.createFamilyCalls.isEmpty)

        viewModel.babyName = "糖糖"
        _ = await viewModel.proceed()
        viewModel.consentAccepted = true
        let consentSuccess = await viewModel.proceed()

        XCTAssertTrue(consentSuccess)
        XCTAssertEqual(service.consentCalls.count, 1)
        XCTAssertEqual(service.consentCalls.first?.0, ChildDataConsent.currentVersion)
        XCTAssertEqual(service.createFamilyCalls, ["豆豆的家"])
        XCTAssertEqual(service.createBabyCalls.count, 1)
        XCTAssertEqual(viewModel.currentStep, .backup)
        XCTAssertTrue(viewModel.hasChildDataConsent)
    }

    func testJoinFamilyPathCallsJoinBeforeConsent() async {
        let service = MockOnboardingService()
        let viewModel = makeViewModel(service: service)
        viewModel.nickname = "外婆"
        _ = await viewModel.proceed()

        viewModel.familyPath = .join
        viewModel.inviteCode = "123456"
        viewModel.selectedRelation = .grandma
        let joinSuccess = await viewModel.proceed()

        XCTAssertTrue(joinSuccess)
        XCTAssertEqual(viewModel.currentStep, .baby)
        XCTAssertEqual(service.joinCalls.count, 1)
        XCTAssertEqual(viewModel.familyId, "fam_join_001")
    }

    func testConsentStepRequiresCheckbox() async {
        let viewModel = makeViewModel()
        viewModel.currentStep = .consent
        viewModel.consentAccepted = false

        let success = await viewModel.proceed()
        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.validationMessage, L10n.string("onboarding.validation.consent_required"))
    }

    func testFinishOnboardingMarksProgress() {
        let progressStore = InMemoryOnboardingProgressStore()
        let viewModel = makeViewModel(progressStore: progressStore)
        viewModel.currentStep = .backup

        XCTAssertTrue(viewModel.finishOnboarding())
        XCTAssertTrue(progressStore.hasCompleted(userId: "usr_test_001"))
    }

    func testShouldPresentOnboardingForNewUser() {
        let progressStore = InMemoryOnboardingProgressStore()
        let session = makeSession(isNewUser: true)
        XCTAssertTrue(OnboardingViewModel.shouldPresentOnboarding(session: session, progressStore: progressStore))
    }

    func testShouldNotPresentAfterCompletion() {
        let progressStore = InMemoryOnboardingProgressStore()
        progressStore.markCompleted(userId: "usr_test_001")
        let session = makeSession(isNewUser: false)
        XCTAssertFalse(OnboardingViewModel.shouldPresentOnboarding(session: session, progressStore: progressStore))
    }

    func testGoBackFromFamilyToProfile() {
        let viewModel = makeViewModel()
        viewModel.currentStep = .family
        viewModel.goBack()
        XCTAssertEqual(viewModel.currentStep, .profile)
    }
}

final class ChildDataConsentGateTests: XCTestCase {
    func testCameraBlockedWithoutConsent() {
        let profile = UserProfile(
            nickname: "测试",
            avatarUrl: nil,
            region: "cn",
            consents: UserConsents(childData: false)
        )
        XCTAssertFalse(ChildDataConsentGate.isFeatureAllowed(.camera, profile: profile))
    }

    func testCameraAllowedWithConsent() {
        let profile = UserProfile(
            nickname: "测试",
            avatarUrl: nil,
            region: "cn",
            consents: UserConsents(childData: true)
        )
        XCTAssertTrue(ChildDataConsentGate.isFeatureAllowed(.camera, profile: profile))
    }

    func testFeedAndAIWriteOpsBlockedWithoutConsent() {
        let profile = UserProfile(
            nickname: "测试",
            avatarUrl: nil,
            region: "cn",
            consents: UserConsents(childData: false)
        )
        XCTAssertFalse(ChildDataConsentGate.isFeatureAllowed(.feedPublish, profile: profile))
        XCTAssertFalse(ChildDataConsentGate.isFeatureAllowed(.feedEngagement, profile: profile))
        XCTAssertFalse(ChildDataConsentGate.isFeatureAllowed(.aiSubmit, profile: profile))
    }

    func testFeedAndAIWriteOpsAllowedWithConsent() {
        let profile = UserProfile(
            nickname: "测试",
            avatarUrl: nil,
            region: "cn",
            consents: UserConsents(childData: true)
        )
        XCTAssertTrue(ChildDataConsentGate.isFeatureAllowed(.feedPublish, profile: profile))
        XCTAssertTrue(ChildDataConsentGate.isFeatureAllowed(.feedEngagement, profile: profile))
        XCTAssertTrue(ChildDataConsentGate.isFeatureAllowed(.aiSubmit, profile: profile))
    }

    func testDetectsConsentRequiredAPIError() {
        let error = APIError(
            code: .accountConsentRequired,
            message: "consent required",
            httpStatusCode: 422
        )
        XCTAssertTrue(ChildDataConsentGate.requiresConsent(for: error))
    }
}
