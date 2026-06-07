import DesignSystem
import SwiftUI

/// AI 玩法页合规页脚：算法备案摘要 + 深度合成说明入口（CN 区，COMP-01）。
public struct ComplianceFooterView: View {
    @ObservedObject private var store: ComplianceFooterStore
    @State private var presentedURL: URL?

    public init(complianceService: any ComplianceConfigServing, region: AppRegion = .cn) {
        store = ComplianceFooterStore(complianceService: complianceService, region: region)
    }

    public var body: some View {
        Group {
            if store.region == .cn {
                footerContent
            }
        }
        .task {
            await store.load()
        }
        .sheet(item: $presentedURL) { url in
            SafariView(url: url)
        }
    }

    private var footerContent: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Divider()

            Text(L10n.string("ai.compliance.algorithm_filing"))
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)

            Text(store.algorithmFilingDisplayText)
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let deepSynthesisURL = store.compliance.deepSynthesisURL {
                Button {
                    presentedURL = deepSynthesisURL
                } label: {
                    HStack(spacing: DSSpacing.xxs) {
                        Text(L10n.string("ai.compliance.deep_synthesis"))
                            .font(DSTypography.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(DSColors.primary)
                }
                .accessibilityIdentifier("aiComplianceDeepSynthesisLink")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(DSColors.surface)
        .accessibilityIdentifier("aiComplianceFooter")
    }
}

@MainActor
final class ComplianceFooterStore: ObservableObject {
    @Published private(set) var compliance: ComplianceConfig
    let region: AppRegion

    private let complianceService: any ComplianceConfigServing

    init(complianceService: any ComplianceConfigServing, region: AppRegion) {
        self.complianceService = complianceService
        self.region = region
        self.compliance = ComplianceConfig.defaults(for: region)
    }

    var algorithmFilingDisplayText: String {
        compliance.algorithmFilingSummary ?? ComplianceConfig.algorithmPendingText
    }

    func load() async {
        guard region == .cn else { return }
        do {
            compliance = try await complianceService.fetchComplianceConfig()
        } catch {
            // 保留 bundled defaults
        }
    }
}
