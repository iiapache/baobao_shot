import SwiftUI

/// 权限被拒后的引导视图：说明文案 +「前往设置」。
public struct PermissionPromptView: View {
    private let type: PermissionType
    private let manager: any PermissionManager
    private let onDismiss: () -> Void

    public init(
        type: PermissionType,
        manager: any PermissionManager,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.type = type
        self.manager = manager
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: type.systemImageName)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(type.settingsTitle)
                .font(.headline)

            Text(type.settingsMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("前往设置") {
                _ = manager.openSettings(for: type)
                onDismiss()
            }
            .buttonStyle(.borderedProminent)

            Button("暂不", role: .cancel) {
                onDismiss()
            }
        }
        .padding(24)
    }
}
