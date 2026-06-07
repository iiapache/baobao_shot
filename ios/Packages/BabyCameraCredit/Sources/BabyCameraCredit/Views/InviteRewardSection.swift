import DesignSystem
import SwiftUI

/// PRD §4.11.1 邀请新用户赠 50 积分说明卡片。
public struct InviteRewardSection: View {
    private let onInvite: () -> Void

    public init(onInvite: @escaping () -> Void = {}) {
        self.onInvite = onInvite
    }

    public var body: some View {
        DSCard(
            title: "邀请好友得积分",
            subtitle: "被邀请方完成实名认证后，双方各得 \(SignInCredits.inviteRewardCredits) 积分"
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Label("不限邀请次数", systemImage: "person.2.fill")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                Label("积分自动到账，可在流水查看", systemImage: "clock.arrow.circlepath")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)

                DSButton("去邀请家人", style: .secondary, systemImage: "qrcode") {
                    onInvite()
                }
            }
        }
        .accessibilityIdentifier("InviteRewardSection")
    }
}
