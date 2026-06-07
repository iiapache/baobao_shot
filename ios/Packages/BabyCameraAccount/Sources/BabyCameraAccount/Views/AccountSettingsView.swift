import DesignSystem
import SwiftUI

public struct AccountSettingsView: View {
    @ObservedObject private var coordinator: AccountCoordinator
    @State private var showDeleteAccount = false

    public init(coordinator: AccountCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        List {
            if let session = coordinator.session {
                Section(L10n.string("account.section")) {
                    DSListRow(
                        icon: "person.circle.fill",
                        title: session.profile?.nickname ?? L10n.string("account.nickname_unset"),
                        subtitle: session.userId
                    )
                }
            }

            Section {
                DSButton(L10n.string("account.logout"), style: .secondary) {
                    Task { await coordinator.handleLogout() }
                }
                .accessibilityIdentifier("logoutButton")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                NavigationLink {
                    DeleteAccountView(
                        viewModel: coordinator.makeDeleteAccountViewModel()
                    ) {
                        Task { await coordinator.handleLogout() }
                    }
                } label: {
                    Label(L10n.string("account.delete.link"), systemImage: "trash")
                        .foregroundStyle(DSColors.error)
                }
                .accessibilityIdentifier("deleteAccountLink")
            }
        }
        .navigationTitle(L10n.string("account.settings.title"))
    }
}
