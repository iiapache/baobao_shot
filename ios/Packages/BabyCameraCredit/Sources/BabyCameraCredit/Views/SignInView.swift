import DesignSystem
import SwiftUI

public struct SignInView: View {
    @ObservedObject private var viewModel: SignInViewModel
    private let onInviteFriends: () -> Void

    public init(
        viewModel: SignInViewModel,
        onInviteFriends: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onInviteFriends = onInviteFriends
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                statusCard
                streakLadder
                InviteRewardSection(onInvite: onInviteFriends)
            }
            .padding(DSSpacing.md)
        }
        .background(DSColors.background)
        .navigationTitle("每日签到")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("SignInView")
        .task {
            await viewModel.refresh()
        }
        .alert("提示", isPresented: errorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var statusCard: some View {
        DSCard(title: "今日签到", subtitle: viewModel.todayCreditsHint) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                if let result = viewModel.completedResult {
                    successBanner(result)
                }

                DSButton(
                    signInButtonTitle,
                    style: .primary,
                    systemImage: "calendar.badge.checkmark",
                    isLoading: viewModel.phase == .signingIn,
                    isDisabled: !viewModel.signInAvailable || viewModel.phase == .signingIn
                ) {
                    Task { await viewModel.signIn() }
                }
            }
        }
    }

    private var signInButtonTitle: String {
        if viewModel.completedResult != nil {
            return "今日已签到"
        }
        return viewModel.signInAvailable ? "立即签到" : "今日已签到"
    }

    private func successBanner(_ result: SignInResult) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(DSColors.success)
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("+\(result.grantedCredits) 积分")
                    .font(DSTypography.headline)
                    .foregroundStyle(DSColors.success)
                Text("已连续签到 \(result.streak) 天")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("签到成功，获得 \(result.grantedCredits) 积分，连续 \(result.streak) 天")
    }

    private var streakLadder: some View {
        DSCard(
            title: "连签奖励",
            subtitle: "连续签到每日递增，最高 \(SignInCredits.maxCredits) 积分/天"
        ) {
            VStack(spacing: DSSpacing.xs) {
                ForEach(SignInCredits.ladder, id: \.day) { entry in
                    streakRow(day: entry.day, credits: entry.credits)
                }
                Text("第 16 天起维持 \(SignInCredits.maxCredits) 积分/天")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, DSSpacing.xxs)
            }
        }
    }

    private func streakRow(day: Int, credits: Int) -> some View {
        let isActive = activeDay == day
        return HStack {
            Text("第 \(day) 天")
                .font(DSTypography.listTitle)
                .foregroundStyle(isActive ? DSColors.primary : DSColors.textPrimary)
            Spacer()
            Text("\(credits) 积分")
                .font(DSTypography.listTitle.monospacedDigit())
                .foregroundStyle(isActive ? DSColors.primary : DSColors.textSecondary)
        }
        .padding(.vertical, DSSpacing.xxs)
        .padding(.horizontal, DSSpacing.xs)
        .background(isActive ? DSColors.primary.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius / 2))
        .accessibilityLabel("第 \(day) 天 \(credits) 积分\(isActive ? "，当前档位" : "")")
    }

    private var activeDay: Int? {
        if let result = viewModel.completedResult {
            return min(result.streak, SignInCredits.displayLadderDays)
        }
        if viewModel.signInAvailable, viewModel.currentStreak > 0 {
            return min(viewModel.currentStreak + 1, SignInCredits.displayLadderDays)
        }
        if !viewModel.signInAvailable, viewModel.currentStreak > 0 {
            return min(viewModel.currentStreak, SignInCredits.displayLadderDays)
        }
        return viewModel.signInAvailable ? 1 : nil
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}
