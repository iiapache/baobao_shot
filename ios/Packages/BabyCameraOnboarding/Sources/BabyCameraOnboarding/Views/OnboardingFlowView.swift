import BabyCameraAccount
import BabyCameraBaby
import BabyCameraFamily
import BabyCameraNetwork
import DesignSystem
import SwiftUI

public struct OnboardingFlowView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @ObservedObject private var coordinator: AccountCoordinator
    @State private var showScanner = false

    private let onCompleted: (AuthSession) -> Void

    public init(
        session: AuthSession,
        coordinator: AccountCoordinator,
        service: OnboardingService = OnboardingService(),
        progressStore: any OnboardingProgressStoring = UserDefaultsOnboardingProgressStore(),
        currentBabyStore: CurrentBabyEnvironment = CurrentBabyEnvironment(restorePersistedSelection: false),
        onCompleted: @escaping (AuthSession) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: OnboardingViewModel(
                session: session,
                service: service,
                progressStore: progressStore,
                currentBabyStore: currentBabyStore
            )
        )
        self.coordinator = coordinator
        self.onCompleted = onCompleted
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                ScrollView {
                    stepContent
                        .padding(DSSpacing.lg)
                }
                footer
            }
            .background(DSColors.background)
            .navigationTitle(L10n.string("onboarding.title"))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("onboardingFlowView")
            .sheet(isPresented: $showScanner) {
                QRScannerView(
                    onScan: { content in
                        viewModel.handleScannedInvite(content)
                        showScanner = false
                    },
                    onCancel: { showScanner = false }
                )
                .ignoresSafeArea()
            }
            .alert(L10n.string("common.alert.title"), isPresented: validationBinding) {
                Button(L10n.string("common.ok"), role: .cancel) {}
            } message: {
                Text(viewModel.validationMessage ?? "")
            }
            .alert(L10n.string("common.alert.operation_failed"), isPresented: errorBinding) {
                Button(L10n.string("common.ok"), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: DSSpacing.sm) {
            ProgressView(
                value: Double(viewModel.currentStep.stepIndex),
                total: Double(OnboardingStep.totalSteps)
            )
            .tint(DSColors.primary)

            Text(
                L10n.string(
                    "common.step_progress",
                    viewModel.currentStep.stepIndex,
                    OnboardingStep.totalSteps,
                    viewModel.currentStep.title
                )
            )
            .font(DSTypography.caption)
            .foregroundStyle(DSColors.textSecondary)
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.md)
        .background(DSColors.surface)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .profile:
            OnboardingProfileStepView(
                nickname: $viewModel.nickname,
                selectedRelation: $viewModel.selectedRelation
            )
        case .family:
            OnboardingFamilyStepView(
                familyPath: $viewModel.familyPath,
                familyName: $viewModel.familyName,
                inviteCode: $viewModel.inviteCode,
                onScanTapped: { showScanner = true }
            )
        case .baby:
            OnboardingBabyStepView(
                name: $viewModel.babyName,
                birthDate: $viewModel.babyBirthDate,
                gender: $viewModel.babyGender
            )
        case .consent:
            OnboardingConsentStepView(consentAccepted: $viewModel.consentAccepted)
        case .backup:
            OnboardingBackupStepView(acknowledged: $viewModel.backupReminderAcknowledged)
        }
    }

    private var footer: some View {
        VStack(spacing: DSSpacing.sm) {
            DSButton(
                viewModel.primaryButtonTitle,
                style: .primary,
                size: .large,
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.canProceed
            ) {
                Task {
                    if viewModel.currentStep == .backup {
                        if viewModel.finishOnboarding() {
                            let updatedSession = AuthSession(
                                userId: viewModel.session.userId,
                                isNewUser: false,
                                profile: viewModel.profile
                            )
                            coordinator.completeOnboarding(updatedSession)
                            onCompleted(updatedSession)
                        }
                    } else if await viewModel.proceed() {
                        // step advanced inside view model
                    }
                }
            }
            .accessibilityIdentifier("onboardingPrimaryButton")

            if viewModel.canGoBack {
                DSButton(L10n.string("onboarding.back"), style: .ghost, size: .medium) {
                    viewModel.goBack()
                }
            }
        }
        .padding(DSSpacing.lg)
        .background(DSColors.surface)
    }

    private var validationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.validationMessage != nil },
            set: { if !$0 { viewModel.validationMessage = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
