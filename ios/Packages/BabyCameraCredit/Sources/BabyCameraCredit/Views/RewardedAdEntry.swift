import SwiftUI

/// 「看广告得积分」入口（PRD §4.11.5 激励视频主动触发）。
public struct RewardedAdEntry: View {
    @ObservedObject private var adManager: AdManager
    private let title: String
    private let onRewardGranted: (AdRewardGrant) -> Void
    private let onFailure: (Error) -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(
        adManager: AdManager,
        title: String = "看广告得积分",
        onRewardGranted: @escaping (AdRewardGrant) -> Void = { _ in },
        onFailure: @escaping (Error) -> Void = { _ in }
    ) {
        self.adManager = adManager
        self.title = title
        self.onRewardGranted = onRewardGranted
        self.onFailure = onFailure
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await watchAd() }
            } label: {
                HStack {
                    if isLoading || adManager.isShowingAd {
                        ProgressView()
                    }
                    Text(title)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || adManager.isShowingAd)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func watchAd() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let outcome = try await adManager.showRewardedAd()
            onRewardGranted(outcome.grant)
        } catch {
            errorMessage = localizedMessage(for: error)
            onFailure(error)
        }
    }

    private func localizedMessage(for error: Error) -> String {
        switch error {
        case AdManagerError.rewardNotEarned:
            return "未完整观看，无法获得积分"
        case AdManagerError.notAuthenticated:
            return "请先登录"
        case AdManagerError.reportFailed(let message):
            return "奖励上报失败：\(message)"
        default:
            return "广告加载失败，请稍后重试"
        }
    }
}
