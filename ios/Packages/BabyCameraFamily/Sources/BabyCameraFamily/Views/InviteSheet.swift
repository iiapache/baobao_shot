import DesignSystem
import SwiftUI

public struct InviteSheet: View {
    @ObservedObject private var viewModel: InviteViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: InviteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.lg) {
                    if let invitation = viewModel.invitation {
                        invitationContent(invitation)
                    } else {
                        emptyState
                    }
                }
                .padding(DSSpacing.lg)
            }
            .background(DSColors.background)
            .navigationTitle("邀请家人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("提示", isPresented: errorBinding) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task {
            if viewModel.invitation == nil {
                await viewModel.generateInvitation()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DSSpacing.md) {
            if viewModel.isLoading {
                DSLoadingView(message: "生成邀请码…")
            } else {
                DSEmptyState(
                    systemImage: "qrcode",
                    title: "邀请家人加入",
                    message: "生成邀请码后，家人可扫码或输入 6 位码加入家庭。",
                    actionTitle: "生成邀请码"
                ) {
                    Task { await viewModel.generateInvitation() }
                }
            }
        }
    }

    @ViewBuilder
    private func invitationContent(_ invitation: FamilyInvitation) -> some View {
        VStack(spacing: DSSpacing.lg) {
            if let qrImage = viewModel.qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(DSSpacing.md)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
                    .accessibilityLabel("邀请二维码")
            }

            VStack(spacing: DSSpacing.xs) {
                Text("邀请码")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                Text(invitation.code)
                    .font(DSTypography.title)
                    .monospaced()
                    .foregroundStyle(DSColors.textPrimary)
                    .kerning(4)
            }

            Text("有效期至 \(formatExpireAt(invitation.expireAt)) · 可用 \(invitation.maxUses - invitation.usedCount) 次")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
                .multilineTextAlignment(.center)

            DSButton(
                viewModel.didCopyCode ? "已复制" : "复制邀请码",
                style: .secondary,
                systemImage: viewModel.didCopyCode ? "checkmark" : "doc.on.doc"
            ) {
                viewModel.copyInviteCode()
            }

            DSButton(
                "重新生成",
                style: .ghost,
                isLoading: viewModel.isLoading
            ) {
                Task { await viewModel.generateInvitation() }
            }

            if viewModel.isLoading {
                ProgressView()
            }

            DSButton("作废邀请码", style: .destructive, size: .small) {
                Task { await viewModel.revokeInvitation() }
            }
        }
    }

    private func formatExpireAt(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            display.locale = Locale(identifier: "zh_CN")
            return display.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            display.locale = Locale(identifier: "zh_CN")
            return display.string(from: date)
        }
        return iso
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
