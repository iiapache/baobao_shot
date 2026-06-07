import DesignSystem
import SwiftUI

/// Mock 相机界面：无需真机摄像头权限。
struct MockCameraView: View {
    @ObservedObject var store: P2E2EFlowStore

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(DSColors.primary)
                .accessibilityIdentifier("mockCameraPreview")
                .accessibilityLabel("相机预览")
                .accessibilityHint("Mock 模式下显示占位预览")

            Text("Mock 相机")
                .font(DSTypography.title2)
                .foregroundStyle(DSColors.textPrimary)

            if store.offlineMode {
                Label("离线模式", systemImage: "wifi.slash")
                    .font(DSTypography.subheadline)
                    .foregroundStyle(DSColors.textSecondary)
                    .accessibilityIdentifier("offlineStatusLabel")
            }

            Text(store.statusMessage)
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
                .accessibilityIdentifier("p2e2eStatusLabel")

            Text("已完成 \(store.completedCycles) 轮")
                .font(DSTypography.body)
                .accessibilityIdentifier("completedCyclesLabel")

            Button {
                store.mockCapturePhoto()
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
            .accessibilityHint("模拟拍摄一张照片并进入编辑流程")

            Button {
                store.openTimeline()
            } label: {
                Label("查看 Timeline", systemImage: "calendar")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("openTimelineButton")
            .accessibilityLabel("查看 Timeline")
            .accessibilityHint("打开成长时间线浏览已拍照片")
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.background)
        .accessibilityIdentifier("mockCameraView")
        .accessibilityLabel("Mock 相机")
    }
}
