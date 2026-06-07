import DesignSystem
import SwiftUI

/// 长按评论弹层：支持 @ 提及家人。
public struct FeedCommentComposerView: View {
    @Binding private var draft: String
    private let mentionCandidates: [FeedMentionCandidate]
    private let onSubmit: () -> Void
    private let onCancel: () -> Void

    public init(
        draft: Binding<String>,
        mentionCandidates: [FeedMentionCandidate],
        onSubmit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._draft = draft
        self.mentionCandidates = mentionCandidates
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TextEditor(text: $draft)
                    .frame(minHeight: 120)
                    .padding(DSSpacing.xs)
                    .background(DSColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))

                if !mentionCandidates.isEmpty {
                    Text("@ 提及家人")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DSSpacing.xs) {
                            ForEach(mentionCandidates) { candidate in
                                Button {
                                    draft = MentionResolver.insertMention(candidate, into: draft)
                                } label: {
                                    Text("@\(candidate.nickname)")
                                        .font(DSTypography.caption)
                                        .padding(.horizontal, DSSpacing.sm)
                                        .padding(.vertical, DSSpacing.xxs)
                                        .background(DSColors.primary.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(DSSpacing.md)
            .navigationTitle("写评论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发送", action: onSubmit)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
