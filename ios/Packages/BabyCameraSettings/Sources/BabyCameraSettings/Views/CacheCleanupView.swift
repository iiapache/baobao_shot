import DesignSystem
import SwiftUI

public struct CacheCleanupView: View {
    @ObservedObject private var viewModel: CacheCleanupViewModel

    public init(viewModel: CacheCleanupViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section {
                Text(L10n.localizedKey("settings.cache.description"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(L10n.string("settings.cache.usage_section")) {
                metricsContent
            }

            Section {
                DSButton(L10n.string("settings.cache.button"), style: .destructive, systemImage: "trash") {
                    viewModel.requestClear()
                }
                .disabled(!canClear)
                .accessibilityIdentifier("cacheCleanupButton")
            }
        }
        .navigationTitle(L10n.string("settings.cache.title"))
        .accessibilityIdentifier("cacheCleanupView")
        .task {
            await viewModel.refresh()
        }
        .confirmationDialog(
            L10n.string("settings.cache.confirm_title"),
            isPresented: $viewModel.showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string("common.clear"), role: .destructive) {
                Task { await viewModel.confirmClear() }
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.localizedKey("settings.cache.confirm_message"))
        }
    }

    @ViewBuilder
    private var metricsContent: some View {
        switch viewModel.state {
        case .loading:
            HStack {
                ProgressView()
                Text(L10n.localizedKey("settings.cache.calculating"))
                    .font(DSTypography.body)
                    .foregroundStyle(DSColors.textSecondary)
            }

        case .cleared:
            clearedMetricsContent

        case .ready(let metrics):
            readyMetricsContent(metrics)

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(DSColors.warning)
                .accessibilityIdentifier("cacheCleanupError")
        }
    }

    private var clearedMetricsContent: some View {
        Group {
            metricsRows(
                CacheCleanupMetrics(
                    totalSizeBytes: 0,
                    thumbnailSizeBytes: 0,
                    webSocketSizeBytes: 0,
                    thumbnailMetrics: .init(hits: 0, misses: 0)
                )
            )
            Label(L10n.localizedKey("settings.cache.cleared"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(DSColors.success)
                .accessibilityIdentifier("cacheClearedBanner")
        }
    }

    private func readyMetricsContent(_ metrics: CacheCleanupMetrics) -> some View {
        metricsRows(metrics)
    }

    private func metricsRows(_ metrics: CacheCleanupMetrics) -> some View {
        Group {
            metricRow(
                title: L10n.string("settings.cache.total"),
                value: CacheCleanupViewModel.formattedSize(metrics.totalSizeBytes),
                identifier: "cacheTotalSize"
            )
            metricRow(
                title: L10n.string("settings.cache.thumbnail"),
                value: CacheCleanupViewModel.formattedSize(metrics.thumbnailSizeBytes),
                identifier: "cacheThumbnailSize"
            )
            metricRow(
                title: L10n.string("settings.cache.websocket"),
                value: CacheCleanupViewModel.formattedSize(metrics.webSocketSizeBytes),
                identifier: "cacheWebSocketSize"
            )
            metricRow(
                title: L10n.string("settings.cache.hit_rate"),
                value: CacheCleanupViewModel.formattedHitRate(metrics.thumbnailHitRate),
                identifier: "cacheHitRate"
            )
            metricRow(
                title: L10n.string("settings.cache.hit_miss"),
                value: "\(metrics.thumbnailMetrics.hits) / \(metrics.thumbnailMetrics.misses)",
                identifier: "cacheHitMissCounts"
            )
        }
    }

    private var canClear: Bool {
        switch viewModel.state {
        case .ready(let metrics):
            return metrics.totalSizeBytes > 0 || metrics.thumbnailMetrics.totalRequests > 0
        case .cleared:
            return false
        case .loading, .failed:
            return false
        }
    }

    private func metricRow(title: String, value: String, identifier: String) -> some View {
        HStack {
            Text(title)
                .font(DSTypography.body)
            Spacer()
            Text(value)
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(DSColors.textSecondary)
        }
        .accessibilityIdentifier(identifier)
    }
}
