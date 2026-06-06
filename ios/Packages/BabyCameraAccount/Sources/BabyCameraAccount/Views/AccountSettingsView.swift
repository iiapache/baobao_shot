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
                Section("账号") {
                    DSListRow(
                        icon: "person.circle.fill",
                        title: session.profile?.nickname ?? "未设置昵称",
                        subtitle: session.userId
                    )
                }
            }

            Section {
                DSButton("退出登录", style: .secondary) {
                    Task { await coordinator.handleLogout() }
                }
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
                    Label("注销账号", systemImage: "trash")
                        .foregroundStyle(DSColors.error)
                }
            }
        }
        .navigationTitle("账号设置")
    }
}
