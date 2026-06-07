import Foundation
import SwiftUI

/// 相机相关用户偏好（PRD §4.3.2：默认仅元数据，不烧入像素）。
public struct CameraSettings: Equatable, Sendable, Codable {
    public var burnInWatermark: Bool

    public static let `default` = CameraSettings(burnInWatermark: false)

    public init(burnInWatermark: Bool = false) {
        self.burnInWatermark = burnInWatermark
    }
}

/// 相机设置持久化（UserDefaults），供设置页 toggle 与拍摄管线读取。
@MainActor
public final class CameraSettingsStore: ObservableObject {
    public static let burnInWatermarkDefaultsKey = "com.babycamera.camera.burnInWatermark"

    @Published public var burnInWatermark: Bool {
        didSet {
            UserDefaults.standard.set(burnInWatermark, forKey: Self.burnInWatermarkDefaultsKey)
        }
    }

    public var settings: CameraSettings {
        CameraSettings(burnInWatermark: burnInWatermark)
    }

    public init(restorePersisted: Bool = true) {
        if restorePersisted {
            burnInWatermark = UserDefaults.standard.bool(forKey: Self.burnInWatermarkDefaultsKey)
        } else {
            burnInWatermark = false
        }
    }
}

/// 设置页：「烧入水印」开关（默认关 — 浮层仅作预览元数据）。
public struct CameraSettingsView: View {
    @ObservedObject private var settingsStore: CameraSettingsStore

    public init(settingsStore: CameraSettingsStore) {
        self.settingsStore = settingsStore
    }

    public var body: some View {
        Toggle(isOn: $settingsStore.burnInWatermark) {
            VStack(alignment: .leading, spacing: 4) {
                Text("烧入水印")
                Text("开启后，宝宝小名与成长天数会写入照片像素；默认仅保存为元数据。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("cameraBurnInWatermarkToggle")
    }
}
