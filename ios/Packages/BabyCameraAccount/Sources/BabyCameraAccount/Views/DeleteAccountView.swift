import DesignSystem
import SwiftUI

public struct DeleteAccountView: View {
    @ObservedObject private var viewModel: DeleteAccountViewModel
    @Environment(\.dismiss) private var dismiss
    private let onDeleted: () -> Void

    @State private var showConfirmation = false
    @State private var showSuccess = false

    public init(
        viewModel: DeleteAccountViewModel,
        onDeleted: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onDeleted = onDeleted
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text("注销账号")
                    .font(DSTypography.title)
                    .foregroundStyle(DSColors.textPrimary)

                Text("注销后 7 天内可撤销。到期后将永久删除账号及关联数据，此操作不可恢复。")
                    .font(DSTypography.body)
                    .foregroundStyle(DSColors.textSecondary)

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    bullet("家庭组中的照片与动态将不可访问")
                    bullet("积分余额与订阅权益将失效")
                    bullet("本地缓存数据将在下次启动时清除")
                }

                DSButton("确认注销账号", style: .destructive, isLoading: viewModel.isLoading) {
                    showConfirmation = true
                }
            }
            .padding(DSSpacing.lg)
        }
        .background(DSColors.background)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "确定要注销账号吗？",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("注销账号", role: .destructive) {
                Task { await performDeletion() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("7 天内可在设置中撤销注销。")
        }
        .alert("注销已提交", isPresented: $showSuccess) {
            Button("知道了") {
                onDeleted()
                dismiss()
            }
        } message: {
            if let result = viewModel.deletionResult {
                Text("将于 \(result.scheduledAt) 完成注销。在此之前可撤销。")
            }
        }
        .alert("注销失败", isPresented: errorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.xs) {
            Text("•")
                .foregroundStyle(DSColors.textSecondary)
            Text(text)
                .font(DSTypography.subheadline)
                .foregroundStyle(DSColors.textSecondary)
        }
    }

    private func performDeletion() async {
        if await viewModel.confirmDeletion() {
            showSuccess = true
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
