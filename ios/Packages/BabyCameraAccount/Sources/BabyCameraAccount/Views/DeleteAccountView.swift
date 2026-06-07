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
                Text(L10n.localizedKey("account.delete.title"))
                    .font(DSTypography.title)
                    .foregroundStyle(DSColors.textPrimary)

                Text(L10n.localizedKey("account.delete.description"))
                    .font(DSTypography.body)
                    .foregroundStyle(DSColors.textSecondary)

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    bullet(L10n.string("account.delete.bullet.photos"))
                    bullet(L10n.string("account.delete.bullet.credits"))
                    bullet(L10n.string("account.delete.bullet.cache"))
                }

                DSButton(L10n.string("account.delete.confirm_button"), style: .destructive, isLoading: viewModel.isLoading) {
                    showConfirmation = true
                }
                .accessibilityIdentifier("confirmDeleteAccountButton")
            }
            .padding(DSSpacing.lg)
        }
        .background(DSColors.background)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            L10n.string("account.delete.confirm_title"),
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string("account.delete.link"), role: .destructive) {
                Task { await performDeletion() }
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.localizedKey("account.delete.confirm_message"))
        }
        .alert(L10n.string("account.delete.submitted_title"), isPresented: $showSuccess) {
            Button(L10n.string("common.ok")) {
                onDeleted()
                dismiss()
            }
        } message: {
            if let result = viewModel.deletionResult {
                Text(L10n.string("account.delete.submitted_message", result.scheduledAt))
            }
        }
        .alert(L10n.string("account.delete.failed_title"), isPresented: errorBinding) {
            Button(L10n.string("common.ok"), role: .cancel) {}
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
