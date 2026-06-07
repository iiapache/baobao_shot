import DesignSystem
import SwiftUI

public struct AITaskProgressView: View {
    @ObservedObject private var viewModel: AITaskProgressViewModel

    private let onDone: () -> Void

    public init(
        viewModel: AITaskProgressViewModel,
        onDone: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .tracking, .appealing:
                trackingView
            case .succeeded:
                succeededView
            case let .failure(presentation):
                failureView(presentation)
            }
        }
        .background(DSColors.background)
        .navigationTitle(viewModel.playName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("AITaskProgressView")
        .task {
            await viewModel.start()
        }
        .sheet(isPresented: $viewModel.isAppealSheetPresented) {
            appealSheet
        }
        .alert("申诉失败", isPresented: appealErrorBinding) {
            Button("知道了", role: .cancel) {
                viewModel.clearAppealError()
            }
        } message: {
            Text(viewModel.appealErrorMessage ?? "")
        }
    }

    private var trackingView: some View {
        DSLoadingView(
            message: viewModel.state == .appealing ? "提交申诉中…" : trackingMessage,
            style: .fullScreen
        )
    }

    private var trackingMessage: String {
        guard let snapshot = viewModel.snapshot else {
            return "任务处理中…"
        }
        switch snapshot.phase {
        case .submitted:
            return "任务已提交，等待处理…"
        case .pending:
            return "排队中，请稍候…"
        case .running:
            return "正在生成，请稍候…"
        default:
            return "任务处理中…"
        }
    }

    private var succeededView: some View {
        DSEmptyState(
            systemImage: "checkmark.circle.fill",
            title: "生成完成",
            message: "结果已就绪，可在相册中查看。",
            actionTitle: "完成",
            action: onDone
        )
    }

    @ViewBuilder
    private func failureView(_ presentation: AITaskFailurePresentation) -> some View {
        ScrollView {
            VStack(spacing: DSSpacing.md) {
                DSErrorView(
                    kind: errorKind(for: presentation.kind),
                    title: presentation.title,
                    message: presentation.message,
                    actionTitle: presentation.canAppeal ? nil : "完成",
                    action: presentation.canAppeal ? nil : onDone
                )
                .frame(minHeight: 220)

                if let refund = presentation.creditRefund {
                    creditRefundBanner(refund)
                }

                if presentation.canAppeal {
                    DSButton("提交申诉", style: .primary) {
                        viewModel.presentAppealSheet()
                    }
                    .padding(.horizontal, DSSpacing.md)
                }

                if presentation.kind == .appealed {
                    DSButton("完成", style: .secondary) {
                        onDone()
                    }
                    .padding(.horizontal, DSSpacing.md)
                }
            }
            .padding(.vertical, DSSpacing.md)
        }
    }

    private func creditRefundBanner(_ refund: AITaskCreditRefundInfo) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(DSColors.success)
            Text(refund.message)
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
        }
        .padding(DSSpacing.sm)
        .background(DSColors.success.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        .padding(.horizontal, DSSpacing.md)
        .accessibilityIdentifier("ai_task_credit_refund_banner")
    }

    private func errorKind(for kind: AITaskFailureKind) -> DSErrorView.Kind {
        switch kind {
        case .modelFailed:
            return .generic
        case .rejected:
            return .auditRejected
        case .appealed:
            return .generic
        }
    }

    private var appealSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text("请说明你认为审核有误的原因，我们将在 24 小时内处理。")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)

                TextEditor(text: $viewModel.appealReason)
                    .frame(minHeight: 120)
                    .padding(DSSpacing.xs)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius)
                            .stroke(DSColors.textTertiary.opacity(0.35), lineWidth: 1)
                    )
                    .accessibilityIdentifier("ai_task_appeal_reason")

                Spacer()
            }
            .padding(DSSpacing.md)
            .navigationTitle("提交申诉")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        viewModel.dismissAppealSheet()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") {
                        Task { await viewModel.submitAppeal() }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var appealErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.appealErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearAppealError()
                }
            }
        )
    }
}
