import BabyCameraAccount
import BabyCameraFamily
import BabyCameraNotification
import DesignSystem
import SwiftUI

/// 设置中心根视图（PRD §4.15 / T6.10）。
public struct SettingsRootView: View {
    private let context: SettingsIntegrationContext

    public init(context: SettingsIntegrationContext) {
        self.context = context
    }

    public var body: some View {
        List {
            Section(L10n.string("settings.section.account_family")) {
                NavigationLink {
                    AccountSettingsView(coordinator: context.accountCoordinator)
                } label: {
                    Label(L10n.localizedKey("settings.account"), systemImage: "person.crop.circle")
                }
                .accessibilityIdentifier("settingsAccountLink")
                .accessibilityLabel(L10n.string("settings.account"))
                .accessibilityHint(L10n.string("settings.account.hint"))

                if let familyViewModel = context.makeFamilyMembersViewModel() {
                    NavigationLink {
                        FamilyMembersView(viewModel: familyViewModel)
                    } label: {
                        Label(L10n.localizedKey("settings.family"), systemImage: "person.3.fill")
                    }
                    .accessibilityIdentifier("settingsFamilyLink")
                    .accessibilityLabel(L10n.string("settings.family"))
                    .accessibilityHint(L10n.string("settings.family.hint"))
                } else {
                    Label(L10n.localizedKey("settings.family"), systemImage: "person.3.fill")
                        .foregroundStyle(DSColors.textSecondary)
                        .accessibilityIdentifier("settingsFamilyUnavailable")
                        .accessibilityLabel(L10n.string("settings.family.unavailable"))
                }
            }

            Section(L10n.string("settings.section.privacy_data")) {
                NavigationLink {
                    PrivacySettingsView(
                        viewModel: PrivacySettingsViewModel(
                            profile: context.session.profile,
                            permissionManager: context.permissionManager,
                            complianceService: context.complianceService
                        )
                    )
                } label: {
                    Label(L10n.localizedKey("settings.privacy"), systemImage: "hand.raised.fill")
                }
                .accessibilityIdentifier("settingsPrivacyLink")
                .accessibilityLabel(L10n.string("settings.privacy"))
                .accessibilityHint(L10n.string("settings.privacy.hint"))

                NavigationLink {
                    DataSettingsView(
                        dataExportViewModel: context.makeDataExportViewModel(),
                        cacheCleanupViewModel: context.makeCacheCleanupViewModel(),
                        backupTargetsViewModel: context.makeBackupTargetsViewModel(),
                        uninstallReminderStore: context.makeUninstallReminderStore()
                    )
                } label: {
                    Label(L10n.localizedKey("settings.data"), systemImage: "externaldrive")
                }
                .accessibilityIdentifier("settingsDataLink")
                .accessibilityLabel(L10n.string("settings.data"))
                .accessibilityHint(L10n.string("settings.data.hint"))
            }

            Section(L10n.string("settings.section.notification_about")) {
                NavigationLink {
                    NotificationCategorySettingsView(
                        store: context.makeNotificationCategoryStore()
                    )
                } label: {
                    Label(L10n.localizedKey("settings.notification"), systemImage: "bell.badge.fill")
                }
                .accessibilityIdentifier("settingsNotificationLink")
                .accessibilityLabel(L10n.string("settings.notification"))
                .accessibilityHint(L10n.string("settings.notification.hint"))

                NavigationLink {
                    AboutSettingsView(
                        store: AboutSettingsStore(
                            complianceService: context.complianceService,
                            versionInfo: context.versionInfo
                        ),
                        feedbackViewModel: context.makeFeedbackViewModel()
                    )
                } label: {
                    Label(L10n.localizedKey("settings.about"), systemImage: "info.circle.fill")
                }
                .accessibilityIdentifier("settingsAboutLink")
                .accessibilityLabel(L10n.string("settings.about"))
                .accessibilityHint(L10n.string("settings.about.hint"))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DSColors.surfaceGrouped)
        .navigationTitle(L10n.string("settings.root.title"))
        .accessibilityIdentifier("settingsRootView")
        .accessibilityLabel(L10n.string("settings.root.title"))
    }
}
