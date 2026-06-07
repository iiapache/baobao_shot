import BabyCameraNotification
import DesignSystem
import SwiftUI

/// 数据管理入口（T6.10 壳；清理/备份由 T6.12 实现）。
public struct DataSettingsView: View {
    private let dataExportViewModel: DataExportViewModel?
    private let cacheCleanupViewModel: CacheCleanupViewModel?
    private let backupTargetsViewModel: BackupTargetsManagementViewModel?
    @ObservedObject private var uninstallReminderStore: UninstallReminderStore

    public init(
        dataExportViewModel: DataExportViewModel? = nil,
        cacheCleanupViewModel: CacheCleanupViewModel? = nil,
        backupTargetsViewModel: BackupTargetsManagementViewModel? = nil,
        uninstallReminderStore: UninstallReminderStore
    ) {
        self.dataExportViewModel = dataExportViewModel
        self.cacheCleanupViewModel = cacheCleanupViewModel
        self.backupTargetsViewModel = backupTargetsViewModel
        self.uninstallReminderStore = uninstallReminderStore
    }

    public var body: some View {
        List {
            Section {
                uninstallWarning
            }

            Section {
                uninstallReminderToggle
            } header: {
                Text(L10n.localizedKey("settings.data.uninstall_reminder"))
            } footer: {
                Text(
                    L10n.string(
                        "settings.data.uninstall_reminder_footer",
                        UninstallReminderCoordinator.reminderIntervalDays
                    )
                )
            }

            Section(L10n.string("settings.data.management")) {
                if let dataExportViewModel {
                    NavigationLink {
                        DataExportView(viewModel: dataExportViewModel)
                    } label: {
                        Label(L10n.localizedKey("settings.data.export"), systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("dataExportLink")
                } else {
                    Label(L10n.localizedKey("settings.data.export"), systemImage: "square.and.arrow.up")
                        .foregroundStyle(DSColors.textSecondary)
                        .accessibilityIdentifier("dataExportUnavailable")
                }

                if let cacheCleanupViewModel {
                    NavigationLink {
                        CacheCleanupView(viewModel: cacheCleanupViewModel)
                    } label: {
                        Label(L10n.localizedKey("settings.data.clear_cache"), systemImage: "trash")
                    }
                    .accessibilityIdentifier("dataClearCacheLink")
                } else {
                    Label(L10n.localizedKey("settings.data.clear_cache"), systemImage: "trash")
                        .foregroundStyle(DSColors.textSecondary)
                        .accessibilityIdentifier("dataClearCacheUnavailable")
                }

                if let backupTargetsViewModel {
                    NavigationLink {
                        BackupTargetsManagementView(viewModel: backupTargetsViewModel)
                    } label: {
                        Label(L10n.localizedKey("settings.data.backup_targets"), systemImage: "externaldrive.badge.icloud")
                    }
                    .accessibilityIdentifier("dataBackupTargetsLink")
                } else {
                    Label(L10n.localizedKey("settings.data.backup_targets"), systemImage: "externaldrive.badge.icloud")
                        .foregroundStyle(DSColors.textSecondary)
                        .accessibilityIdentifier("dataBackupTargetsUnavailable")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DSColors.surfaceGrouped)
        .navigationTitle(L10n.string("settings.data.title"))
        .accessibilityIdentifier("dataSettingsView")
    }

    private var uninstallWarning: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Label(L10n.localizedKey("settings.data.uninstall_backup_first"), systemImage: "exclamationmark.triangle.fill")
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(DSColors.warning)

                Text(L10n.localizedKey("settings.data.uninstall_warning"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let backupTargetsViewModel {
                    NavigationLink {
                        BackupTargetsManagementView(viewModel: backupTargetsViewModel)
                    } label: {
                        Text(L10n.localizedKey("settings.data.go_backup"))
                            .font(DSTypography.caption)
                            .foregroundStyle(DSColors.primary)
                    }
                    .accessibilityIdentifier("dataUninstallBackupLink")
                }
            }
        }
        .accessibilityIdentifier("dataUninstallWarning")
    }

    private var uninstallReminderToggle: some View {
        Toggle(isOn: uninstallReminderBinding) {
            Text(L10n.localizedKey("settings.data.enable_uninstall_reminder"))
        }
        .accessibilityIdentifier("dataUninstallReminderToggle")
    }

    private var uninstallReminderBinding: Binding<Bool> {
        Binding(
            get: { uninstallReminderStore.enabled },
            set: { newValue in
                Task { await uninstallReminderStore.setEnabled(newValue) }
            }
        )
    }
}
