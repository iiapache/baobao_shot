import BabyCameraNetwork
import BabyCameraPermissions
import DesignSystem
import SwiftUI

public struct PrivacySettingsView: View {
    @ObservedObject private var viewModel: PrivacySettingsViewModel
    @State private var presentedURL: URL?
    private let permissionRouting: PermissionRouting

    public init(
        viewModel: PrivacySettingsViewModel,
        permissionRouting: PermissionRouting = PermissionRouting()
    ) {
        self.viewModel = viewModel
        self.permissionRouting = permissionRouting
    }

    public var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: L10n.string("settings.privacy.system_permissions"))

            ForEach(Array(PermissionType.allCases.enumerated()), id: \.element) { index, type in
                DSListRow(
                    icon: type.privacySettingsIcon,
                    title: type.privacySettingsLabel,
                    subtitle: viewModel.statusLabel(for: type),
                    showsDivider: index < PermissionType.allCases.count - 1,
                    action: viewModel.needsSettingsPrompt(for: type)
                        ? { _ = permissionRouting.openSettingsIfDenied(type) }
                        : nil
                ) {
                    if viewModel.needsSettingsPrompt(for: type) {
                        Text(L10n.localizedKey("common.go_settings"))
                            .font(DSTypography.caption)
                            .foregroundStyle(DSColors.primary)
                    }
                }
                .accessibilityIdentifier("privacyPermission_\(type.rawValue)")
            }

            SectionHeader(title: L10n.string("settings.privacy.child_policy"))

            DSListRow(
                icon: "figure.and.child.holdinghands",
                title: L10n.string("settings.privacy.child_consent"),
                subtitle: viewModel.hasChildDataConsent
                    ? L10n.string("settings.privacy.consent.agreed", viewModel.childConsentVersion)
                    : L10n.string("settings.privacy.consent.not_agreed"),
                showsDivider: true
            )
            .accessibilityIdentifier("privacyChildConsentRow")

            DSListRow(
                icon: "hand.raised.fill",
                title: L10n.string("settings.about.privacy_policy"),
                subtitle: ComplianceConfig.legalLinkSubtitle(version: viewModel.compliance.privacyPolicyVersion),
                showsDivider: true,
                action: viewModel.compliance.privacyPolicyURL.map { url in { presentedURL = url } }
            ) {
                Image(systemName: "chevron.right")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textTertiary)
            }
            .accessibilityIdentifier("privacyPolicyLink")

            DSListRow(
                icon: "list.bullet.rectangle",
                title: L10n.string("settings.about.third_party_sdk"),
                subtitle: ComplianceConfig.legalLinkSubtitle(version: viewModel.compliance.thirdPartySDKListVersion),
                showsDivider: false,
                action: viewModel.compliance.thirdPartySDKListURL.map { url in { presentedURL = url } }
            ) {
                Image(systemName: "chevron.right")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textTertiary)
            }
            .accessibilityIdentifier("privacyThirdPartySDKLink")
        }
        .background(DSColors.surface)
        .navigationTitle(L10n.string("settings.privacy.title"))
        .task {
            await viewModel.refresh()
        }
        .sheet(item: $presentedURL) { url in
            SafariView(url: url)
        }
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(DSTypography.caption)
            .foregroundStyle(DSColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSSpacing.listRowHorizontalPadding)
            .padding(.top, DSSpacing.md)
            .padding(.bottom, DSSpacing.xs)
    }
}
