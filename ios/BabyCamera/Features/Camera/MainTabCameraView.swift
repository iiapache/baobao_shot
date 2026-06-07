import BabyCameraAccount
import BabyCameraBaby
import BabyCameraCamera
import BabyCameraOnboarding
import Database
import DesignSystem
import SwiftUI

/// 相机 Tab：Consent 门禁 + 真实取景与拍摄入库。
struct MainTabCameraView: View {
    let session: AuthSession
    let appDatabase: AppDatabase
    @ObservedObject var babyStore: CurrentBabyEnvironment
    let onPhotoCaptured: (String) -> Void
    @StateObject private var captureStore: CameraCaptureStore

    init(
        session: AuthSession,
        appDatabase: AppDatabase,
        babyStore: CurrentBabyEnvironment,
        onPhotoCaptured: @escaping (String) -> Void = { _ in }
    ) {
        self.session = session
        self.appDatabase = appDatabase
        self.babyStore = babyStore
        self.onPhotoCaptured = onPhotoCaptured
        _captureStore = StateObject(wrappedValue: CameraCaptureStore(appDatabase: appDatabase))
    }

    var body: some View {
        ConsentGatedContent(feature: .camera, profile: session.profile, userId: session.userId) {
            NavigationStack {
                cameraContent
                    .navigationTitle("相机")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onChange(of: captureStore.latestCapturedPhotoId) { _, photoId in
            guard let photoId else { return }
            onPhotoCaptured(photoId)
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        if let baby = babyStore.currentBaby {
            ZStack(alignment: .bottom) {
                if UITestBootstrap.isEnabled {
                    uitestMockCameraOverlay(baby: baby)
                } else {
                    CameraViewRepresentable(
                        captureStore: captureStore,
                        overlayInfo: CameraOverlayInfo(baby: baby),
                        userId: session.userId,
                        baby: baby
                    )
                    .id(baby.id)
                    .ignoresSafeArea()
                }

                if let statusMessage = captureStore.statusMessage {
                    Text(statusMessage)
                        .font(DSTypography.caption)
                        .foregroundStyle(UITestBootstrap.isEnabled ? DSColors.textSecondary : .white)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.vertical, DSSpacing.sm)
                        .background(UITestBootstrap.isEnabled ? DSColors.surface : Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(.bottom, DSSpacing.xl)
                        .accessibilityIdentifier("cameraStatusLabel")
                }
            }
            .accessibilityIdentifier("mainTabCameraView")
        } else {
            noBabyPlaceholder
        }
    }

    @ViewBuilder
    private func uitestMockCameraOverlay(baby: BabyProfile) -> some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(DSColors.primary)
                .accessibilityIdentifier("mockCameraPreview")

            Text("Mock 相机")
                .font(DSTypography.title2)
                .foregroundStyle(DSColors.textPrimary)

            Button {
                Task {
                    await captureStore.mockCapturePhoto(userId: session.userId, baby: baby)
                }
            } label: {
                Label("Mock 拍照", systemImage: "camera.shutter.button")
                    .font(DSTypography.bodyEmphasis)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(DSColors.primary)
            .accessibilityIdentifier("mockCaptureButton")
            .accessibilityLabel("Mock 拍照")
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.background)
        .accessibilityIdentifier("mockCameraView")
    }

    private var noBabyPlaceholder: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "figure.and.child.holdinghands")
                .font(DSTypography.largeTitle)
                .foregroundStyle(DSColors.primary)

            Text("请先添加宝宝")
                .font(DSTypography.title)
                .foregroundStyle(DSColors.textPrimary)

            Text("完成 onboarding 或同步家庭数据后即可开始拍摄")
                .font(DSTypography.subheadline)
                .foregroundStyle(DSColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.background)
        .accessibilityIdentifier("cameraNoBabyPlaceholder")
    }
}
