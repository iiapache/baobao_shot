import BabyCameraTimeline
import DesignSystem
import SwiftUI

/// P2 端到端根视图：串联 mock 相机、编辑器、Timeline。
struct P2E2ERootView: View {
    @StateObject private var store: P2E2EFlowStore
    @StateObject private var timelineViewModel: TimelineViewModel

    init(offlineMode: Bool = UITestLaunchConfiguration.isOfflineMode) {
        let flowStore = P2E2EFlowStore(offlineMode: offlineMode)
        _store = StateObject(wrappedValue: flowStore)
        _timelineViewModel = StateObject(wrappedValue: TimelineViewModel(
            photoSource: flowStore.photoSource,
            currentBabyStore: flowStore.babyStore,
            initialScale: .day
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("p2e2eRootView")
    }

    @ViewBuilder
    private var content: some View {
        switch store.screen {
        case .mockCamera:
            MockCameraView(store: store)
        case let .editor(photoId, isReEdit):
            PhotoEditorFlowView(store: store, photoId: photoId, isReEdit: isReEdit)
        case .timeline:
            timelineScreen
        }
    }

    private var timelineScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    store.screen = .mockCamera
                } label: {
                    Label("返回相机", systemImage: "camera")
                }
                .accessibilityIdentifier("backToCameraButton")

                Spacer()

                Text("照片 \(store.savedPhotoCount)")
                    .font(DSTypography.caption)
                    .accessibilityIdentifier("timelinePhotoCountLabel")
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)

            GrowthTimelineView(
                viewModel: timelineViewModel,
                onPhotoTap: { item in
                    store.reEditPhoto(id: item.id)
                }
            )
        }
        .accessibilityIdentifier("p2e2eTimelineScreen")
        .task {
            await timelineViewModel.reload()
        }
        .onChange(of: store.savedPhotoCount) { _ in
            Task { await timelineViewModel.reload() }
        }
    }
}

#Preview {
    P2E2ERootView()
}
