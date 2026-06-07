import DesignSystem
import SwiftUI

public struct TakeoverFlow: View {
    @ObservedObject private var viewModel: TakeoverViewModel
    @Environment(\.dismiss) private var dismiss

    private let onCompleted: () -> Void

    public init(
        viewModel: TakeoverViewModel,
        onCompleted: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onCompleted = onCompleted
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .submitting:
                    DSLoadingView(message: submittingMessage)
                case .success where !viewModel.showsVoteProgress:
                    terminalSuccessView
                default:
                    mainContent
                }
            }
            .background(DSColors.background)
            .navigationTitle("管理员接管")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .disabled(viewModel.state.isBusy)
                }
            }
            .confirmationDialog(
                confirmationTitle,
                isPresented: confirmingBinding,
                titleVisibility: .visible
            ) {
                if viewModel.isAdmin {
                    Button("撤销接管", role: .destructive) {
                        Task { await viewModel.confirmCancelObjection() }
                    }
                } else {
                    Button("发起投票", role: .destructive) {
                        Task { await viewModel.confirmInitiate() }
                    }
                }
                Button("取消", role: .cancel) {
                    viewModel.cancelConfirmation()
                }
            } message: {
                Text(confirmationMessage)
            }
            .alert("提示", isPresented: errorBinding) {
                Button("知道了", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.state.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let vote = viewModel.vote, vote.isActive {
            voteProgressView(vote)
        } else if viewModel.canInitiate {
            initiateView
        } else if viewModel.isAdmin {
            adminIdleView
        } else {
            ineligibleView
        }
    }

    private var initiateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text("当管理员超过 30 天未登录时，家人可发起接管投票。需 ≥50% 家人同意，且 7 天无异议期后自动生效。")
                    .font(DSTypography.body)
                    .foregroundStyle(DSColors.textSecondary)

                pushPreviewCard(
                    title: viewModel.initiatePushCopy.title,
                    body: viewModel.initiatePushCopy.body
                )

                DSButton("发起接管投票", style: .primary) {
                    viewModel.requestInitiateConfirmation()
                }
                .disabled(viewModel.state.isBusy)
            }
            .padding(DSSpacing.lg)
        }
    }

    private func voteProgressView(_ vote: TakeoverVoteResult) -> some View {
        List {
            Section {
                Text(voteStatusDescription(vote))
                    .font(DSTypography.body)
                    .foregroundStyle(DSColors.textSecondary)
            }

            Section("投票进度") {
                LabeledContent("赞成", value: "\(vote.approveCount) / \(vote.requiredApprovals)")
                LabeledContent("反对", value: "\(vote.rejectCount)")
                LabeledContent("可投票家人", value: "\(vote.eligibleVoters)")
            }

            if vote.status == .objectionPeriod {
                Section {
                    pushPreviewCard(
                        title: viewModel.objectionPeriodPushCopy.title,
                        body: viewModel.objectionPeriodPushCopy.body
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if viewModel.isAdmin {
                    Section {
                        Button(role: .destructive) {
                            viewModel.requestCancelObjectionConfirmation()
                        } label: {
                            Text("撤销接管")
                        }
                    }
                }
            }

            if vote.status == .voting, viewModel.canInitiate {
                Section {
                    Button {
                        Task { await viewModel.vote(approve: true) }
                    } label: {
                        Label("赞成", systemImage: "hand.thumbsup")
                    }
                    .disabled(viewModel.state.isBusy)

                    Button {
                        Task { await viewModel.vote(approve: false) }
                    } label: {
                        Label("反对", systemImage: "hand.thumbsdown")
                    }
                    .disabled(viewModel.state.isBusy)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var adminIdleView: some View {
        DSEmptyState(
            systemImage: "shield.checkered",
            title: "暂无接管投票",
            message: "若家人发起接管并进入异议期，你可以在此撤销。"
        )
    }

    private var ineligibleView: some View {
        DSEmptyState(
            systemImage: "person.crop.circle.badge.exclamationmark",
            title: "无法参与接管",
            message: "仅家庭成员可发起或参与管理员接管投票。"
        )
    }

    private var terminalSuccessView: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DSColors.success)

            Text(terminalSuccessTitle)
                .font(DSTypography.title)

            Text(terminalSuccessMessage)
                .font(DSTypography.body)
                .foregroundStyle(DSColors.textSecondary)
                .multilineTextAlignment(.center)

            DSButton("完成") {
                onCompleted()
                dismiss()
            }
        }
        .padding(DSSpacing.lg)
    }

    private func pushPreviewCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("推送通知预览（占位）")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
            Text(title)
                .font(DSTypography.bodyEmphasis)
            Text(body)
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
    }

    private func voteStatusDescription(_ vote: TakeoverVoteResult) -> String {
        switch vote.status {
        case .voting:
            return "接管投票进行中，请家人尽快投票。"
        case .objectionPeriod:
            if let endsAt = vote.objectionEndsAt {
                return "投票已通过，进入 7 天异议期，至 \(formatDate(endsAt))。"
            }
            return "投票已通过，进入 7 天异议期。"
        default:
            return ""
        }
    }

    private var confirmationTitle: String {
        viewModel.isAdmin ? "撤销接管？" : "发起接管投票？"
    }

    private var confirmationMessage: String {
        if viewModel.isAdmin {
            return "撤销后本次接管流程将终止，你将继续担任管理员。"
        }
        return "发起后将通知所有家人参与投票，请确认管理员确实长期失联。"
    }

    private var submittingMessage: String {
        if viewModel.isAdmin {
            return "正在撤销…"
        }
        if viewModel.vote == nil {
            return "正在发起…"
        }
        return "正在提交投票…"
    }

    private var terminalSuccessTitle: String {
        switch viewModel.vote?.status {
        case .objectionPeriod:
            return "已进入异议期"
        case .cancelled:
            return "接管已撤销"
        case .rejected:
            return "投票未通过"
        default:
            return "操作成功"
        }
    }

    private var terminalSuccessMessage: String {
        switch viewModel.vote?.status {
        case .objectionPeriod:
            return FamilyPushNotificationCopy.takeoverObjectionPeriodBody(days: 7)
        case .cancelled:
            return FamilyPushNotificationCopy.takeoverCancelledBody
        case .rejected:
            return "赞成票未达要求，管理员保持不变。"
        default:
            return "家人将收到相关推送通知。"
        }
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        }
        return iso
    }

    private var confirmingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state == .confirming },
            set: { if !$0 { viewModel.cancelConfirmation() } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.errorMessage != nil },
            set: { if !$0 { viewModel.dismissTerminalState() } }
        )
    }
}
