import BabyCameraNetwork
import DesignSystem
import SwiftUI

/// 智能文案三选一（T5.16）。
public struct CaptionPickerView: View {
    public let candidates: [CaptionCandidate]
    public let remainingToday: Int
    public let limitMessage: String?
    public let onSelect: (CaptionCandidate) -> Void
    public let onDismiss: () -> Void

    public init(
        candidates: [CaptionCandidate],
        remainingToday: Int,
        limitMessage: String? = nil,
        onSelect: @escaping (CaptionCandidate) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.candidates = candidates
        self.remainingToday = remainingToday
        self.limitMessage = limitMessage
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    if let limitMessage {
                        limitBanner(message: limitMessage)
                    }

                    Text("选择一条文案")
                        .font(DSTypography.headline)
                        .foregroundStyle(DSColors.textPrimary)

                    Text("今日剩余 \(remainingToday) 次")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)

                    ForEach(Array(candidates.prefix(3).enumerated()), id: \.offset) { index, candidate in
                        Button {
                            onSelect(candidate)
                        } label: {
                            candidateCard(candidate, index: index + 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DSSpacing.md)
            }
            .navigationTitle("智能文案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private func limitBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DSColors.warning)
            Text(message)
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.sm)
        .background(DSColors.primaryMuted)
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    private func candidateCard(_ candidate: CaptionCandidate, index: Int) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("候选 \(index)")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textTertiary)

            Text(candidate.composedText)
                .font(DSTypography.body)
                .foregroundStyle(DSColors.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DSSpacing.sm)
        .background(DSColors.surfaceGrouped)
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        .accessibilityLabel("候选 \(index)：\(candidate.composedText)")
    }
}
