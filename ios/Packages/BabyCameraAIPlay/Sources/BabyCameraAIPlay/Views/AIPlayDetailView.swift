import DesignSystem
import SwiftUI

public struct AIPlayDetailView<RestrictedSubmit: View>: View {
    @ObservedObject private var viewModel: AIPlayDetailViewModel

    private let onRecharge: () -> Void
    private let onSignIn: () -> Void
    private let onTaskSubmitted: (AITaskCreatedData) -> Void
    private let submitAllowed: Bool
    private let restrictedSubmitContent: () -> RestrictedSubmit

    public init(
        viewModel: AIPlayDetailViewModel,
        onRecharge: @escaping () -> Void = {},
        onSignIn: @escaping () -> Void = {},
        onTaskSubmitted: @escaping (AITaskCreatedData) -> Void = { _ in },
        submitAllowed: Bool = true,
        @ViewBuilder restrictedSubmitContent: @escaping () -> RestrictedSubmit
    ) {
        self.viewModel = viewModel
        self.onRecharge = onRecharge
        self.onSignIn = onSignIn
        self.onTaskSubmitted = onTaskSubmitted
        self.submitAllowed = submitAllowed
        self.restrictedSubmitContent = restrictedSubmitContent
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .loadingPreview where viewModel.preview == nil:
                DSLoadingView(message: "加载积分预览…", style: .fullScreen)
            case .submitting:
                DSLoadingView(message: "提交任务中…", style: .fullScreen)
            case .submitted:
                submittedView
            case .error where viewModel.preview == nil:
                DSErrorView(
                    kind: .generic,
                    message: viewModel.state.errorMessage,
                    actionTitle: "重试"
                ) {
                    Task { await viewModel.loadPreview() }
                }
            default:
                detailContent
            }
        }
        .background(DSColors.background)
        .navigationTitle(viewModel.play.name)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("AIPlayDetailView")
        .task {
            await viewModel.loadPreview()
        }
        .onChange(of: viewModel.pendingNavigation) { navigation in
            guard let navigation else { return }
            switch navigation {
            case .recharge:
                onRecharge()
            case .signIn:
                onSignIn()
            }
            viewModel.clearPendingNavigation()
        }
        .onChange(of: viewModel.createdTask) { task in
            guard let task else { return }
            onTaskSubmitted(task)
        }
        .confirmationDialog(
            "确认提交 AI 任务？",
            isPresented: confirmingBinding,
            titleVisibility: .visible
        ) {
            Button("确认提交") {
                Task { await viewModel.confirmSubmit() }
            }
            Button("取消", role: .cancel) {
                viewModel.cancelConfirmation()
            }
        } message: {
            if let preview = viewModel.preview {
                Text(
                    "将消耗 \(preview.costCredits) 积分，提交后余额约 \(preview.balanceAfter) 积分。"
                )
            }
        }
        .alert("提示", isPresented: errorBinding) {
            Button("知道了", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.state.errorMessage ?? "")
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                playSummary

                if viewModel.play.kind == .video, !viewModel.play.durationTiers.isEmpty {
                    durationPicker
                }

                if let preview = viewModel.preview {
                    creditSummary(preview)
                    if !preview.hasSufficientCredit {
                        insufficientCreditBanner(preview)
                    } else {
                        signInHint(preview)
                    }
                }

                if submitAllowed {
                    DSButton(
                        submitButtonTitle,
                        style: .primary,
                        isLoading: viewModel.state == .loadingPreview,
                        isDisabled: viewModel.preview == nil || viewModel.state.isBusy
                    ) {
                        viewModel.requestSubmit()
                    }
                } else {
                    restrictedSubmitContent()
                }
            }
            .padding(DSSpacing.md)
        }
    }

    private var playSummary: some View {
        DSCard(title: viewModel.play.name, subtitle: viewModel.play.description) {
            HStack(spacing: DSSpacing.xs) {
                Label(
                    viewModel.play.kind.displayName,
                    systemImage: viewModel.play.kind.systemImageName
                )
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Text(viewModel.play.creditLabel)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.primary)
            }
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("视频时长")
                .font(DSTypography.subheadline)
                .foregroundStyle(DSColors.textPrimary)

            ForEach(viewModel.play.durationTiers.sorted { $0.durationSeconds < $1.durationSeconds }) { tier in
                DSListRow(
                    title: "\(tier.durationSeconds) 秒",
                    subtitle: "\(tier.creditCost) 积分",
                    action: {
                        viewModel.selectDuration(tier.durationSeconds)
                    }
                ) {
                    if viewModel.selectedDurationSeconds == tier.durationSeconds {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DSColors.primary)
                    }
                }
            }
        }
    }

    private func creditSummary(_ preview: CreditPreview) -> some View {
        DSCard(title: "积分预览", subtitle: nil) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                summaryRow(title: "当前余额", value: "\(preview.balance) 积分")
                summaryRow(title: "本次消耗", value: "\(preview.costCredits) 积分")
                summaryRow(title: "提交后余额", value: "\(preview.balanceAfter) 积分")
            }
        }
    }

    @ViewBuilder
    private func signInHint(_ preview: CreditPreview) -> some View {
        if let hint = preview.signInHint {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(DSColors.warning)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(hint)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)
                    Button("去签到") {
                        viewModel.requestSignIn()
                    }
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.primary)
                }
                Spacer()
            }
            .padding(DSSpacing.sm)
            .background(DSColors.primaryMuted.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
            .accessibilityIdentifier("ai_play_sign_in_hint")
        }
    }

    private func insufficientCreditBanner(_ preview: CreditPreview) -> some View {
        DSErrorView(
            kind: .insufficientCredit,
            message: "还需 \(max(preview.costCredits - preview.balance, 0)) 积分，当前余额 \(preview.balance) 积分",
            actionTitle: "去充值",
            secondaryActionTitle: preview.signInAvailable ? "去签到" : nil,
            style: .banner,
            action: onRecharge,
            secondaryAction: preview.signInAvailable ? onSignIn : nil
        )
        .accessibilityIdentifier("ai_play_insufficient_credit_banner")
    }

    private var submittedView: some View {
        DSEmptyState(
            systemImage: "checkmark.circle.fill",
            title: "任务已提交",
            message: submittedMessage,
            actionTitle: nil
        )
    }

    private var submittedMessage: String {
        guard let task = viewModel.createdTask else {
            return "AI 任务已进入处理队列。"
        }
        var message = "任务编号 \(task.taskId)"
        if let seconds = task.estimatedSeconds {
            message += "，预计 \(seconds) 秒内完成"
        }
        return message
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
            Text(value)
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textPrimary)
        }
    }

    private var submitButtonTitle: String {
        guard let preview = viewModel.preview else {
            return "开始生成"
        }
        if preview.hasSufficientCredit {
            return "开始生成（\(preview.costCredits) 积分）"
        }
        return "积分不足，去充值"
    }

    private var confirmingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state == .confirming },
            set: { isPresented in
                if !isPresented, viewModel.state == .confirming {
                    viewModel.cancelConfirmation()
                }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearError()
                }
            }
        )
    }
}

public extension AIPlayDetailView where RestrictedSubmit == EmptyView {
    init(
        viewModel: AIPlayDetailViewModel,
        onRecharge: @escaping () -> Void = {},
        onSignIn: @escaping () -> Void = {},
        onTaskSubmitted: @escaping (AITaskCreatedData) -> Void = { _ in }
    ) {
        self.init(
            viewModel: viewModel,
            onRecharge: onRecharge,
            onSignIn: onSignIn,
            onTaskSubmitted: onTaskSubmitted,
            submitAllowed: true,
            restrictedSubmitContent: { EmptyView() }
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AIPlayDetailView(
            viewModel: AIPlayDetailViewModel(
                play: AIPlay(
                    id: "ghibli_kid",
                    name: "宫崎骏风",
                    description: "风格化图像",
                    kind: .image,
                    creditCost: 8,
                    available: true
                ),
                submissionContext: AIPlaySubmissionContext(
                    inputObjectKey: "ai-tmp/usr_preview/photo.heic",
                    familyId: "fam_preview"
                ),
                previewService: PreviewCreditPreviewService(),
                submitService: PreviewAITaskSubmitService()
            )
        )
    }
}

@MainActor
private struct PreviewCreditPreviewService: CreditPreviewServing {
    func preview(play: AIPlay, durationSeconds: Int?) async throws -> CreditPreview {
        CreditPreview(
            costCredits: CreditCostCalculator.cost(for: play, durationSeconds: durationSeconds),
            balance: 5,
            signInAvailable: true
        )
    }
}

@MainActor
private struct PreviewAITaskSubmitService: AITaskSubmitting {
    func submit(
        play: AIPlay,
        context: AIPlaySubmissionContext,
        durationSeconds: Int?
    ) async throws -> AITaskCreatedData {
        AITaskCreatedData(
            taskId: "tsk_preview",
            state: "credit_held",
            costCredits: 8,
            balanceAfter: 0,
            estimatedSeconds: 18
        )
    }
}
#endif
