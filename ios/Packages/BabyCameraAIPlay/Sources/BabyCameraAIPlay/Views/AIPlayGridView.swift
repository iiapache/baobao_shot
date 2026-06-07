import DesignSystem
import SwiftUI

public struct AIPlayGridView: View {
    @StateObject private var viewModel: AIPlayGridViewModel
    private let onSelectPlay: ((AIPlay) -> Void)?

    public init(
        viewModel: AIPlayGridViewModel,
        onSelectPlay: ((AIPlay) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectPlay = onSelectPlay
    }

    public var body: some View {
        Group {
            if viewModel.isLoading, viewModel.plays.isEmpty {
                DSLoadingView(message: "加载玩法中…", style: .fullScreen)
            } else if viewModel.plays.isEmpty {
                DSEmptyState(
                    systemImage: "sparkles",
                    title: "暂无可用玩法",
                    message: viewModel.errorMessage ?? "当前区域暂无可用的 AI 玩法，请稍后再试。",
                    actionTitle: viewModel.errorMessage == nil ? nil : "重试"
                ) {
                    Task { await viewModel.load(forceRefresh: true) }
                }
            } else {
                content
            }
        }
        .background(DSColors.background)
        .accessibilityIdentifier("AIPlayGridView")
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load(forceRefresh: true)
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: DSSpacing.md) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DSSpacing.md)
                }

                ForEach(viewModel.plays) { play in
                    Button {
                        onSelectPlay?(play)
                    } label: {
                        AIPlayCardView(
                            play: play,
                            isPinned: viewModel.pinnedPlayIDs.contains(play.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DSSpacing.md)
        }
    }
}

#if DEBUG
#Preview {
    AIPlayGridView(
        viewModel: AIPlayGridViewModel(
            catalogService: PreviewPlayCatalogService()
        )
    )
}

@MainActor
private struct PreviewPlayCatalogService: PlayCatalogServing {
    func fetchCatalog(forceRefresh: Bool) async throws -> PlaysCatalog {
        PlaysCatalog(
            version: "preview",
            region: .cn,
            ttlSeconds: 300,
            plays: [
                AIPlay(
                    id: "ghibli_kid",
                    name: "宫崎骏风",
                    description: "风格化图像",
                    kind: .image,
                    creditCost: 8,
                    available: true
                ),
            ]
        )
    }

    func cachedCatalog() async -> PlaysCatalog? { nil }
}
#endif
