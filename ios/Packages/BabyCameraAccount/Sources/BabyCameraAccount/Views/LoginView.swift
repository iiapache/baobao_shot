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
        .alert("登录失败", isPresented: errorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DSColors.primary)
            Text("宝宝成长相机")
                .font(DSTypography.title)
                .foregroundStyle(DSColors.textPrimary)
            Text("记录宝宝每一个珍贵瞬间")
                .font(DSTypography.subheadline)
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSSpacing.xl)
    }

    private var appleSignInSection: some View {
        DSButton(
            "通过 Apple 登录",
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
    }

    private var divider: some View {
        HStack {
            Rectangle().fill(DSColors.separator).frame(height: 1)
            Text("或")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
            Rectangle().fill(DSColors.separator).frame(height: 1)
        }
    }

    private var phoneLoginSection: some View {
        VStack(spacing: DSSpacing.md) {
            TextField("手机号", text: $viewModel.phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(DSSpacing.md)
                .background(DSColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))

            HStack(spacing: DSSpacing.sm) {
                TextField("验证码", text: $viewModel.verificationCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding(DSSpacing.md)
                    .background(DSColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))

                DSButton(
                    viewModel.codeCooldownSeconds > 0 ? "\(viewModel.codeCooldownSeconds)s" : "获取验证码",
                    style: .secondary,
                    size: .small,
                    isLoading: viewModel.isSendingCode,
                    isDisabled: !viewModel.canSendCode
                ) {
                    Task { await viewModel.sendVerificationCode() }
                }
                .frame(width: 120)
            }

            DSButton(
                "手机号登录",
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
