import Foundation

@MainActor
public final class CustomMilestoneViewModel: ObservableObject {
    @Published public private(set) var entries: [MilestoneTimelineEntry] = []
    @Published public private(set) var calendarMarkedDays: Set<String> = []
    @Published public private(set) var pinnedAIPlayIDs: [String] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    public let babyId: String
    public let birthDate: String

    private let repository: any CustomMilestoneRepository
    private let aiPlayRecommender: any MilestoneAIPlayRecommending
    private let calendar: Calendar
    private let referenceDate: Date

    public init(
        babyId: String,
        birthDate: String,
        repository: any CustomMilestoneRepository,
        aiPlayRecommender: any MilestoneAIPlayRecommending = StubMilestoneAIPlayRecommender(),
        calendar: Calendar = .current,
        referenceDate: Date = Date()
    ) {
        self.babyId = babyId
        self.birthDate = birthDate
        self.repository = repository
        self.aiPlayRecommender = aiPlayRecommender
        self.calendar = calendar
        self.referenceDate = referenceDate
    }

    public func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let customMilestones = try await repository.fetchAll(babyId: babyId)
            let merged = MilestoneMerger.mergedEntries(
                birthDate: birthDate,
                babyId: babyId,
                customMilestones: customMilestones,
                referenceDate: referenceDate,
                calendar: calendar
            )
            entries = merged
            calendarMarkedDays = MilestoneMerger.calendarMarkedDayKeys(from: merged, calendar: calendar)
            await refreshPinnedAIPlays(for: referenceDate)
        } catch {
            errorMessage = "加载里程碑失败"
        }
    }

    @discardableResult
    public func create(name: String, date: Date) async -> CustomMilestone? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请输入里程碑名称"
            return nil
        }

        do {
            let milestone = try await repository.create(babyId: babyId, name: trimmed, date: date)
            await reload()
            return milestone
        } catch {
            errorMessage = "创建失败"
            return nil
        }
    }

    public func update(_ milestone: CustomMilestone) async -> Bool {
        do {
            try await repository.update(milestone)
            await reload()
            return true
        } catch {
            errorMessage = "更新失败"
            return false
        }
    }

    public func delete(id: String) async -> Bool {
        do {
            try await repository.delete(id: id)
            await reload()
            return true
        } catch {
            errorMessage = "删除失败"
            return false
        }
    }

    public func entries(on dayKey: String) -> [MilestoneTimelineEntry] {
        entries.filter { $0.dayKey(calendar: calendar) == dayKey }
    }

    public func refreshPinnedAIPlays(for date: Date) async {
        let dayKey = MilestoneDateCodec.dayKey(for: date, calendar: calendar)
        guard calendarMarkedDays.contains(dayKey) else {
            pinnedAIPlayIDs = []
            return
        }
        pinnedAIPlayIDs = await aiPlayRecommender.recommendedPlayIDs(
            babyId: babyId,
            milestoneDate: calendar.startOfDay(for: date)
        )
    }
}
