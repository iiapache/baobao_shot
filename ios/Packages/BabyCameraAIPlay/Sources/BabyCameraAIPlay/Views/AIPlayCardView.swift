import DesignSystem
import SwiftUI

struct AIPlayCardView: View {
    let play: AIPlay
    let isPinned: Bool

    var body: some View {
        DSCard(title: play.name, subtitle: play.description) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack(spacing: DSSpacing.xs) {
                    Label(play.kind.displayName, systemImage: play.kind.systemImageName)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)

                    if isPinned {
                        Text("推荐")
                            .font(DSTypography.caption)
                            .foregroundStyle(DSColors.textOnPrimary)
                            .padding(.horizontal, DSSpacing.xs)
                            .padding(.vertical, 2)
                            .background(DSColors.primary)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text(play.creditLabel)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.primary)
                }

                if play.kind == .video, !play.durationTiers.isEmpty {
                    Text(durationSummary)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ai_play_card_\(play.id)")
    }

    private var durationSummary: String {
        play.durationTiers
            .sorted { $0.durationSeconds < $1.durationSeconds }
            .map { "\($0.durationSeconds)s · \($0.creditCost)积分" }
            .joined(separator: "  ")
    }
}

#if DEBUG
#Preview {
    ScrollView {
        AIPlayCardView(
            play: AIPlay(
                id: "ghibli_kid",
                name: "宫崎骏风",
                description: "风格化图像，720p 输出",
                kind: .image,
                creditCost: 8,
                available: true
            ),
            isPinned: true
        )
        .padding()
    }
    .background(DSColors.background)
}
#endif
