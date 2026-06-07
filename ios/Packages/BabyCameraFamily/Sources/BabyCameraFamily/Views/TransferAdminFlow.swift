import DesignSystem
import SwiftUI

public struct TransferAdminFlow: View {
    @ObservedObject private var viewModel: TransferAdminViewModel
    @Environment(\.dismiss) private var dismiss

    private let onCompleted: () -> Void

    public init(
        viewModel: TransferAdminViewModel,
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
                    DSLoadingView(message: "正在转让…")
                case .success:
                    successView
                default:
                    selectionView
                }
            }
            .background(DSColors.background)
            .navigationTitle("转让管理员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .disabled(viewModel.state.isBusy)
                }
            }
            .confirmationDialog(
                "确认转让管理员？",
                isPresented: confirmingBinding,
                titleVisibility: .visible
            ) {
                Button("确认转让", role: .destructive) {
                    Task { await viewModel.confirmTransfer() }
                }
                Button("取消", role: .cancel) {
                    viewModel.cancelConfirmation()
                }
            } message: {
                if let target = viewModel.targetMember {
                    Text("转让后，\(displayName(target)) 将成为家庭管理员，你将变为普通家人。")
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
    }

    private var selectionView: some View {
        List {
            Section {
                Text("选择一位家人接管管理员权限。转让后立即生效，此操作不可撤销。")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
            }

            Section("可转让给家人") {
                if viewModel.candidates.isEmpty {
                    Text("暂无可转让的家人")
                        .foregroundStyle(DSColors.textSecondary)
                } else {
                    ForEach(viewModel.candidates) { member in
                        Button {
                            viewModel.selectTarget(member)
                            viewModel.requestConfirmation()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                    Text(displayName(member))
                                        .foregroundStyle(DSColors.textPrimary)
                                    Text(member.role.displayName)
                                        .font(DSTypography.caption)
                                        .foregroundStyle(DSColors.textSecondary)
                                }
                                Spacer()
                                if viewModel.targetMember?.id == member.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DSColors.primary)
                                }
                            }
                        }
                        .disabled(viewModel.state.isBusy)
                    }
                }
            }

            if let target = viewModel.targetMember, viewModel.canProceed {
                Section {
                    DSButton("转让管理员", style: .primary) {
                        viewModel.requestConfirmation()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var successView: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DSColors.success)

            Text("转让成功")
                .font(DSTypography.title)
                .foregroundStyle(DSColors.textPrimary)

            if let target = viewModel.targetMember {
                Text("\(displayName(target)) 现在是家庭管理员")
                    .font(DSTypography.body)
                    .foregroundStyle(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            pushPreviewCard

            DSButton("完成") {
                onCompleted()
                dismiss()
            }
        }
        .padding(DSSpacing.lg)
    }

    private var pushPreviewCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("推送通知预览（占位）")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(viewModel.pushCopyForMembers(newAdminName: viewModel.targetMember.map(displayName) ?? "新管理员").title)
                    .font(DSTypography.bodyEmphasis)
                Text(viewModel.pushCopyForMembers(newAdminName: viewModel.targetMember.map(displayName) ?? "新管理员").body)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        }
    }

    private func displayName(_ member: FamilyMember) -> String {
        member.nickname.isEmpty ? member.role.displayName : member.nickname
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
            set: { if !$0 { viewModel.dismissSuccess() } }
        )
    }
}
