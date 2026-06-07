import BabyCameraBaby
import BabyCameraMilestone
import Database
import DesignSystem
import SwiftUI
import UserNotifications

/// 里程碑列表 + 日历 + 本地通知预约（NAV-05）。
struct MainTabMilestoneView: View {
    let appDatabase: AppDatabase
    @ObservedObject var currentBabyStore: CurrentBabyEnvironment

    @StateObject private var holder = MainTabMilestoneHolder()
    @State private var notificationStatus: String?
    @State private var isScheduling = false
    @State private var pendingCount = 0

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                VStack(spacing: 0) {
                    notificationSection
                    Divider()
                    MilestoneListView(viewModel: viewModel)
                }
            } else if holder.isLoading {
                DSLoadingView(message: "加载里程碑…")
            } else {
                DSEmptyState(
                    systemImage: "flag.fill",
                    title: "暂无宝宝信息",
                    message: "完成新手引导并添加宝宝后，可查看成长里程碑与预约提醒。"
                )
            }
        }
        .background(DSColors.background)
        .navigationTitle("里程碑")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("mainTabMilestoneScreen")
        .task {
            await bootstrap()
        }
        .onChange(of: currentBabyStore.currentBabyId) { _, _ in
            Task { await bootstrap() }
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("本地通知")
                .font(DSTypography.subheadline)
                .foregroundStyle(DSColors.textPrimary)

            Text("基于宝宝出生日，自动预约未来一年内的内置里程碑提醒（每日 9:00）。")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)

            if let notificationStatus {
                Text(notificationStatus)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.primary)
            }

            HStack(spacing: DSSpacing.md) {
                Button {
                    Task { await scheduleNotifications() }
                } label: {
                    if isScheduling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("预约提醒")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColors.primary)
                .disabled(isScheduling || currentBabyStore.currentBaby == nil)
                .accessibilityIdentifier("milestoneScheduleNotificationsButton")

                if pendingCount > 0 {
                    Text("已预约 \(pendingCount) 条")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.textSecondary)
                        .accessibilityIdentifier("milestonePendingCountLabel")
                }
            }
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColors.surface)
    }

    private func bootstrap() async {
        await MainTabBabyLoader.load(into: currentBabyStore, database: appDatabase)
        await holder.configure(
            baby: currentBabyStore.currentBaby,
            appDatabase: appDatabase
        )
        if let babyId = currentBabyStore.currentBabyId {
            await refreshPendingCount(for: babyId)
        }
    }

    private func scheduleNotifications() async {
        guard let baby = currentBabyStore.currentBaby else { return }
        isScheduling = true
        notificationStatus = nil
        defer { isScheduling = false }

        let center = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            notificationStatus = "无法请求通知权限"
            return
        }

        guard granted else {
            notificationStatus = "请在系统设置中允许通知后重试"
            return
        }

        do {
            let scheduler = MilestoneScheduler()
            let result = try await scheduler.reschedule(
                for: MilestoneSchedulingRequest(
                    babyId: baby.id,
                    birthDate: baby.birthDate
                )
            )
            notificationStatus = "已预约 \(result.scheduledCount) 个里程碑提醒"
            await refreshPendingCount(for: baby.id)
        } catch {
            notificationStatus = "预约失败，请稍后重试"
        }
    }

    private func refreshPendingCount(for babyId: String) async {
        let prefix = MilestoneNotificationIdentifier.babyPrefix(babyId: babyId)
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        pendingCount = pending.filter { $0.identifier.hasPrefix(prefix) }.count
    }
}

@MainActor
private final class MainTabMilestoneHolder: ObservableObject {
    @Published private(set) var viewModel: CustomMilestoneViewModel?
    @Published private(set) var isLoading = false

    func configure(baby: BabyProfile?, appDatabase: AppDatabase) async {
        guard let baby else {
            viewModel = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        let repository = GRDBCustomMilestoneRepository(
            repository: appDatabase.makeMilestoneRepository()
        )
        let model = CustomMilestoneViewModel(
            babyId: baby.id,
            birthDate: baby.birthDate,
            repository: repository
        )
        await model.reload()
        viewModel = model
    }
}
