import BabyCameraAccount
import DesignSystem
import SwiftUI

@main
struct BabyCameraApp: App {
    var body: some Scene {
        WindowGroup {
            AccountRootView { session in
                MainShellView(session: session)
            }
        }
    }
}

private struct MainShellView: View {
    let session: AuthSession
    @EnvironmentObject private var coordinator: AccountCoordinator

    var body: some View {
        NavigationStack {
            VStack(spacing: DSSpacing.lg) {
                Image(systemName: "camera.fill")
                    .font(DSTypography.largeTitle)
                    .foregroundStyle(DSColors.primary)
                Text("宝宝成长相机")
                    .font(DSTypography.title)
                    .foregroundStyle(DSColors.textPrimary)
                Text(session.profile?.nickname ?? "欢迎回来")
                    .font(DSTypography.subheadline)
                    .foregroundStyle(DSColors.textSecondary)

                NavigationLink {
                    AccountSettingsView(coordinator: coordinator)
                } label: {
                    Label("账号设置", systemImage: "person.crop.circle")
                        .font(DSTypography.bodyEmphasis)
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColors.primary)

                NavigationLink {
                    DesignSystemCatalogView()
                } label: {
                    Label("Design System Catalog", systemImage: "paintpalette.fill")
                        .font(DSTypography.bodyEmphasis)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColors.background)
            .navigationTitle("首页")
        }
    }
}

#Preview {
    let coordinator = AccountCoordinator()
    return AccountRootView(coordinator: coordinator) { session in
        MainShellView(session: session)
            .environmentObject(coordinator)
    }
}
