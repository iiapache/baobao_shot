import BabyCameraAccount
import DesignSystem
import SwiftUI
import Widgets

/// P6 端到端 smoke：Widget 四形态 + 设置导出/备份/注销入口（mock，T6.15）。
struct P6E2ERootView: View {
    @StateObject private var coordinator: AccountCoordinator

    init() {
        _coordinator = StateObject(wrappedValue: P6E2EBootstrap.makeCoordinator())
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Widget 形态（smoke）") {
                    ForEach(BabyWidgetKind.allCases, id: \.rawValue) { kind in
                        HStack {
                            Image(systemName: icon(for: kind))
                            VStack(alignment: .leading) {
                                Text(label(for: kind))
                                    .font(DSTypography.bodyEmphasis)
                                Text(kind.rawValue)
                                    .font(DSTypography.caption)
                                    .foregroundStyle(DSColors.textSecondary)
                            }
                        }
                        .accessibilityIdentifier(accessibilityId(for: kind))
                    }
                }

                Section("设置与账号") {
                    NavigationLink {
                        P6SettingsSmokeView(coordinator: coordinator)
                    } label: {
                        Label("设置中心", systemImage: "gearshape.fill")
                    }
                    .accessibilityIdentifier("p6SettingsSmokeLink")
                }
            }
            .navigationTitle("P6 E2E")
        }
        .accessibilityIdentifier("p6e2eRootView")
    }

    private func label(for kind: BabyWidgetKind) -> String {
        switch kind {
        case .small: return "小尺寸"
        case .medium: return "中尺寸"
        case .large: return "大尺寸"
        case .lockScreen: return "锁屏"
        }
    }

    private func icon(for kind: BabyWidgetKind) -> String {
        switch kind {
        case .small: return "square.grid.2x2"
        case .medium: return "rectangle.grid.2x2"
        case .large: return "rectangle.grid.3x2"
        case .lockScreen: return "lock.circle"
        }
    }

    private func accessibilityId(for kind: BabyWidgetKind) -> String {
        switch kind {
        case .small: return "widgetSmokeSmall"
        case .medium: return "widgetSmokeMedium"
        case .large: return "widgetSmokeLarge"
        case .lockScreen: return "widgetSmokeLockScreen"
        }
    }
}

private struct P6SettingsSmokeView: View {
    @ObservedObject var coordinator: AccountCoordinator

    var body: some View {
        List {
            Section("数据") {
                NavigationLink {
                    P6DataExportSmokeView()
                } label: {
                    Label("导出数据", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("dataExportLink")

                NavigationLink {
                    P6BackupTargetsSmokeView()
                } label: {
                    Label("备份目标管理", systemImage: "externaldrive.badge.icloud")
                }
                .accessibilityIdentifier("dataBackupTargetsLink")
            }

            Section("账号") {
                NavigationLink {
                    AccountSettingsView(coordinator: coordinator)
                } label: {
                    Label("账号", systemImage: "person.crop.circle")
                }
                .accessibilityIdentifier("settingsAccountLink")
            }
        }
        .navigationTitle("设置")
        .accessibilityIdentifier("settingsRootView")
    }
}

private struct P6DataExportSmokeView: View {
    var body: some View {
        List {
            Section {
                Text("Mock 导出：zip 含 manifest.json · timeline.html · photos/")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
            }
            Section {
                Button("开始导出") {}
                    .accessibilityIdentifier("dataExportStartButton")
            }
        }
        .navigationTitle("导出数据")
        .accessibilityIdentifier("dataExportView")
    }
}

private struct P6BackupTargetsSmokeView: View {
    var body: some View {
        List {
            Section("备份目标") {
                backupRow(title: "iCloud", id: "backupTarget_iCloud")
                backupRow(title: "百度网盘", id: "backupTarget_baiduPan")
                backupRow(title: "系统相册", id: "backupTarget_photos")
            }
            Section("最近备份") {
                Text("上次成功：mock")
                    .accessibilityIdentifier("backupStatusSummary")
            }
        }
        .navigationTitle("备份目标管理")
        .accessibilityIdentifier("backupTargetsManagementView")
    }

    private func backupRow(title: String, id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: .constant(true))
                .labelsHidden()
        }
        .accessibilityIdentifier(id)
    }
}

#Preview {
    P6E2ERootView()
}
