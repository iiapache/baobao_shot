import BabyCameraAccount
import BabyCameraBaby
import BabyCameraFamily
import BabyCameraNetwork
import DesignSystem
import Foundation

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public var currentStep: OnboardingStep = .profile
    @Published public var nickname = ""
    @Published public var selectedRelation: FamilyRelation = .mom
    @Published public var familyPath: OnboardingFamilyPath = .create
    @Published public var familyName = ""
    @Published public var inviteCode = ""
    @Published public var scannedPayload: String?
    @Published public var babyName = ""
    @Published public var babyBirthDate = Date()
    @Published public var babyGender: BabyGender?
    @Published public var consentAccepted = false
    @Published public var backupReminderAcknowledged = false
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var validationMessage: String?
    @Published public private(set) var familyId: String?
    @Published public private(set) var createdBaby: BabyProfile?
    @Published public private(set) var profile: UserProfile?

    public let session: AuthSession
    private let service: any OnboardingServing
    private let progressStore: any OnboardingProgressStoring
    private let currentBabyStore: CurrentBabyEnvironment

    public init(
        session: AuthSession,
        service: any OnboardingServing,
        progressStore: any OnboardingProgressStoring = UserDefaultsOnboardingProgressStore(),
        currentBabyStore: CurrentBabyEnvironment = CurrentBabyEnvironment(restorePersistedSelection: false)
    ) {
        self.session = session
        self.service = service
        self.progressStore = progressStore
        self.currentBabyStore = currentBabyStore
        self.profile = session.profile
        if let existingNickname = session.profile?.nickname, !existingNickname.isEmpty {
            nickname = existingNickname
        }
    }

    public var hasChildDataConsent: Bool {
        ChildDataConsent.hasValidConsent(userId: session.userId, profile: profile)
    }

    public var canGoBack: Bool {
        currentStep != .profile && !isLoading
    }

    public var primaryButtonTitle: String {
        switch currentStep {
        case .backup:
            L10n.string("onboarding.start")
        default:
            L10n.string("onboarding.next")
        }
    }

    public var canProceed: Bool {
        switch currentStep {
        case .profile:
            !trimmedNickname.isEmpty && !isLoading
        case .family:
            familyStepIsValid && !isLoading
        case .baby:
            babyStepIsValid && !isLoading
        case .consent:
            consentAccepted && !isLoading
        case .backup:
            !isLoading
        }
    }

    public func goBack() {
        guard canGoBack, let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        validationMessage = nil
        errorMessage = nil
        currentStep = previous
    }

    @discardableResult
    public func proceed() async -> Bool {
        validationMessage = nil
        errorMessage = nil

        switch currentStep {
        case .profile:
            return await submitProfileStep()
        case .family:
            return await submitFamilyStep()
        case .baby:
            return advanceToConsentStep()
        case .consent:
            return await submitConsentAndProvision()
        case .backup:
            return finishOnboarding()
        }
    }

    public func handleScannedInvite(_ content: String) {
        scannedPayload = content
        errorMessage = nil
        do {
            inviteCode = try service.extractInviteCode(from: content)
        } catch {
            errorMessage = L10n.string("onboarding.error.qr_unrecognized")
        }
    }

    public func finishOnboarding() -> Bool {
        progressStore.markCompleted(userId: session.userId)
        return true
    }

    public static func shouldPresentOnboarding(
        session: AuthSession,
        progressStore: any OnboardingProgressStoring = UserDefaultsOnboardingProgressStore()
    ) -> Bool {
        if progressStore.hasCompleted(userId: session.userId) {
            return false
        }
        return session.isNewUser
    }

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var familyStepIsValid: Bool {
        switch familyPath {
        case .create:
            !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .join:
            !effectiveInviteCode.isEmpty
        }
    }

    private var babyStepIsValid: Bool {
        BabyFormValidation.validate(
            name: babyName,
            birthDate: BabyFormValidation.birthDateString(from: babyBirthDate)
        ) == nil
    }

    private var effectiveInviteCode: String {
        if !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private func submitProfileStep() async -> Bool {
        guard !trimmedNickname.isEmpty else {
            validationMessage = L10n.string("onboarding.validation.nickname_required")
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let me = try await service.updateProfile(nickname: trimmedNickname)
            profile = UserProfile(
                nickname: me.nickname,
                avatarUrl: me.avatarUrl,
                region: me.region,
                consents: me.consents
            )
            currentStep = .family
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    private func submitFamilyStep() async -> Bool {
        guard familyStepIsValid else {
            validationMessage = familyPath == .create
                ? L10n.string("onboarding.validation.family_name_required")
                : L10n.string("onboarding.validation.invite_required")
            return false
        }

        if familyPath == .create {
            currentStep = .baby
            return true
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result: JoinFamilyResult
            if let scannedPayload, !scannedPayload.isEmpty {
                result = try await service.joinFamily(
                    fromScannedContent: scannedPayload,
                    relation: selectedRelation,
                    nickname: trimmedNickname
                )
            } else {
                result = try await service.joinFamily(
                    code: effectiveInviteCode,
                    relation: selectedRelation,
                    nickname: trimmedNickname
                )
            }
            familyId = result.familyId
            currentStep = .baby
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    private func advanceToConsentStep() -> Bool {
        guard babyStepIsValid else {
            validationMessage = BabyFormValidation.validate(
                name: babyName,
                birthDate: BabyFormValidation.birthDateString(from: babyBirthDate)
            )
            return false
        }
        currentStep = .consent
        return true
    }

    private func submitConsentAndProvision() async -> Bool {
        guard consentAccepted else {
            validationMessage = L10n.string("onboarding.validation.consent_required")
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await service.submitChildDataConsent(
                version: ChildDataConsent.currentVersion,
                accepted: true
            )
            ConsentVersionChecker.recordAgreedVersion(
                ChildDataConsent.currentVersion,
                userId: session.userId
            )
            let me = try await service.refreshProfile()
            profile = UserProfile(
                nickname: me.nickname,
                avatarUrl: me.avatarUrl,
                region: me.region,
                consents: me.consents
            )

            if familyId == nil, familyPath == .create {
                let trimmedFamilyName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
                let family = try await service.createFamily(name: trimmedFamilyName)
                familyId = family.id
            }

            guard let familyId else {
                errorMessage = L10n.string("onboarding.error.family_undetermined")
                return false
            }

            let babyProfile = BabyProfile(
                id: UUID().uuidString,
                familyId: familyId,
                name: BabyFormValidation.trimmedName(babyName),
                gender: babyGender,
                birthDate: BabyFormValidation.birthDateString(from: babyBirthDate)
            )
            let savedBaby = try await service.createBaby(familyId: familyId, profile: babyProfile)
            createdBaby = savedBaby
            currentBabyStore.upsert(savedBaby)
            currentBabyStore.select(babyId: savedBaby.id)

            currentStep = .backup
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            if ChildDataConsentGate.requiresConsent(for: apiError) {
                return L10n.string("onboarding.error.consent_required")
            }
            switch apiError.code {
            case .familyInviteExpired:
                return L10n.string("onboarding.error.invite_expired")
            case .familyInviteUsedUp:
                return L10n.string("onboarding.error.invite_used_up")
            case .familyMemberLimit:
                return L10n.string("onboarding.error.member_limit")
            case .familyAlreadyMember:
                return L10n.string("onboarding.error.already_member")
            default:
                return apiError.message
            }
        }
        return L10n.string("onboarding.error.generic")
    }
}
