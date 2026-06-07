import DesignSystem
import SwiftUI

public struct LoginView: View {
    @ObservedObject private var viewModel: LoginViewModel
    private let onAuthenticated: (AuthSession) -> Void

    public init(
        viewModel: LoginViewModel,
        onAuthenticated: @escaping (AuthSession) -> Void
    ) {
        self.viewModel = viewModel
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                header
                appleSignInSection
                divider
                phoneLoginSection
            }
            .padding(DSSpacing.lg)
        }
        .background(DSColors.background)
        .accessibilityIdentifier("loginView")
        .accessibilityLabel(L10n.string("login.title"))
        .alert(L10n.string("login.failed_title"), isPresented: errorBinding) {
            Button(L10n.string("common.ok"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DSColors.primary)
            Text(L10n.localizedKey("app.name"))
                .font(DSTypography.title)
                .foregroundStyle(DSColors.textPrimary)
            Text(L10n.localizedKey("app.tagline"))
                .font(DSTypography.subheadline)
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSSpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.string("app.name_with_tagline"))
    }

    private var appleSignInSection: some View {
        DSButton(
            L10n.string("login.apple_sign_in"),
            style: .primary,
            systemImage: "apple.logo",
            isLoading: viewModel.isLoading
        ) {
            Task {
                if let session = await viewModel.signInWithApple() {
                    onAuthenticated(session)
                }
            }
        }
        .accessibilityIdentifier("loginAppleButton")
        .accessibilityHint(L10n.string("login.apple_sign_in.hint"))
    }

    private var divider: some View {
        HStack {
            Rectangle().fill(DSColors.separator).frame(height: 1)
            Text(L10n.localizedKey("common.or"))
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
            Rectangle().fill(DSColors.separator).frame(height: 1)
        }
    }

    private var phoneLoginSection: some View {
        VStack(spacing: DSSpacing.md) {
            TextField(L10n.string("login.phone"), text: $viewModel.phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(DSSpacing.md)
                .background(DSColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
                .accessibilityIdentifier("loginPhoneField")
                .accessibilityLabel(L10n.string("login.phone"))
                .accessibilityHint(L10n.string("login.phone.hint"))

            HStack(spacing: DSSpacing.sm) {
                TextField(L10n.string("login.verification_code"), text: $viewModel.verificationCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding(DSSpacing.md)
                    .background(DSColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
                    .accessibilityIdentifier("loginCodeField")
                    .accessibilityLabel(L10n.string("login.verification_code"))
                    .accessibilityHint(L10n.string("login.verification_code.hint"))

                DSButton(
                    viewModel.codeCooldownSeconds > 0
                        ? "\(viewModel.codeCooldownSeconds)s"
                        : L10n.string("login.send_code"),
                    style: .secondary,
                    size: .small,
                    isLoading: viewModel.isSendingCode,
                    isDisabled: !viewModel.canSendCode
                ) {
                    Task { await viewModel.sendVerificationCode() }
                }
                .frame(width: 120)
                .accessibilityIdentifier("loginSendCodeButton")
                .accessibilityHint(L10n.string("login.send_code.hint"))
            }

            DSButton(
                L10n.string("login.phone_submit"),
                style: .primary,
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.canSubmitPhoneLogin
            ) {
                Task {
                    if let session = await viewModel.loginWithPhone() {
                        onAuthenticated(session)
                    }
                }
            }
            .accessibilityIdentifier("loginPhoneSubmitButton")
            .accessibilityHint(L10n.string("login.phone_submit.hint"))
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}
