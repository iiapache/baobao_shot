import BabyCameraBackup
import DesignSystem
import SwiftUI

public struct BackupTargetsManagementView: View {
    @ObservedObject private var viewModel: BackupTargetsManagementViewModel

    public init(viewModel: BackupTargetsManagementViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section {
                Text(L10n.localizedKey("settings.backup.description"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let summary = viewModel.statusSummary {
                Section(L10n.string("settings.backup.recent")) {
                    Text(summary.statusLabel)
                        .font(DSTypography.body)
                        .accessibilityIdentifier("backupStatusSummary")
                }
            }

            Section(L10n.string("settings.backup.targets")) {
                ForEach(viewModel.targets) { item in
                    backupTargetRow(item)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.warning)
                        .accessibilityIdentifier("backupTargetsError")
                }
            }
        }
        .navigationTitle(L10n.string("settings.backup.title"))
        .accessibilityIdentifier("backupTargetsManagementView")
        .overlay {
            if viewModel.isLoading && viewModel.targets.allSatisfy({ !$0.isBound }) {
                ProgressView(L10n.string("common.loading"))
            }
        }
        .task {
            await viewModel.refresh()
        }
    }

    private func backupTargetRow(_ item: BackupTargetItem) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: BackupTargetsManagementViewModel.icon(for: item.kind))
                .foregroundStyle(DSColors.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(BackupTargetsManagementViewModel.title(for: item.kind))
                    .font(DSTypography.bodyEmphasis)
                Text(BackupTargetsManagementViewModel.subtitle(for: item))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
            }

            Spacer()

            if viewModel.isUpdating(item.kind) {
                ProgressView()
            } else {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { item.isBound },
                        set: { enabled in
                            Task { await viewModel.setEnabled(item.kind, enabled: enabled) }
                        }
                    )
                )
                .labelsHidden()
            }
        }
        .accessibilityIdentifier("backupTarget_\(item.kind.rawValue)")
    }
}
