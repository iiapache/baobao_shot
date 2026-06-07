import DesignSystem
import SwiftUI

public struct DataExportView: View {
    @ObservedObject private var viewModel: DataExportViewModel

    public init(viewModel: DataExportViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section {
                Text(L10n.localizedKey("settings.export.description"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(L10n.string("settings.export.progress_section")) {
                progressContent
            }

            Section {
                actionButtons
            }
        }
        .navigationTitle(L10n.string("settings.export.title"))
        .accessibilityIdentifier("dataExportView")
        .sheet(
            isPresented: Binding(
                get: { viewModel.isShareSheetPresented },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissShareSheet()
                    }
                }
            )
        ) {
            if let archiveURL = viewModel.exportedArchiveURL {
                ShareSheet(items: [archiveURL]) {
                    viewModel.dismissShareSheet()
                }
            }
        }
    }

    @ViewBuilder
    private var progressContent: some View {
        switch viewModel.state {
        case .idle:
            DSEmptyState(
                systemImage: "square.and.arrow.up",
                title: L10n.string("settings.export.idle_title"),
                message: L10n.string("settings.export.idle_message")
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

        case .exporting(let progress):
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                ProgressView(value: progress.fractionCompleted) {
                    Text(phaseLabel(progress.phase))
                        .font(DSTypography.bodyEmphasis)
                } currentValueLabel: {
                    Text("\(progress.completedItems)/\(progress.totalItems)")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)
                }
                .accessibilityIdentifier("dataExportProgressBar")

                Text(L10n.localizedKey("settings.export.in_progress_hint"))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
            }
            .padding(.vertical, DSSpacing.xs)

        case .completed:
            Label(L10n.localizedKey("settings.export.completed"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(DSColors.success)
                .font(DSTypography.body)

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(DSColors.warning)
                .font(DSTypography.body)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch viewModel.state {
        case .exporting:
            Button(role: .destructive) {
                viewModel.cancelExport()
            } label: {
                Label(L10n.localizedKey("settings.export.cancel"), systemImage: "xmark.circle")
            }
            .accessibilityIdentifier("dataExportCancelButton")

        case .completed:
            if viewModel.exportedArchiveURL != nil {
                Button {
                    viewModel.isShareSheetPresented = true
                } label: {
                    Label(L10n.localizedKey("settings.export.share"), systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("dataExportShareButton")
            }

            Button {
                viewModel.reset()
            } label: {
                Label(L10n.localizedKey("settings.export.restart"), systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier("dataExportRestartButton")

        case .idle, .failed:
            Button {
                viewModel.startExport()
            } label: {
                Label(L10n.localizedKey("settings.export.start"), systemImage: "square.and.arrow.up.on.square")
            }
            .disabled(!viewModel.canStartExport)
            .accessibilityIdentifier("dataExportStartButton")
        }
    }

    private func phaseLabel(_ phase: DataExportPhase) -> String {
        switch phase {
        case .preparing:
            return L10n.string("settings.export.phase.preparing")
        case .copyingPhotos:
            return L10n.string("settings.export.phase.copying")
        case .writingMetadata:
            return L10n.string("settings.export.phase.metadata")
        case .finalizing:
            return L10n.string("settings.export.phase.finalizing")
        case .completed:
            return L10n.string("settings.export.phase.completed")
        case .failed:
            return L10n.string("settings.export.phase.failed")
        }
    }
}
