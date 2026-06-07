import Foundation

/// 合并内置里程碑与自定义里程碑，供列表与日历标记共用。
public enum MilestoneMerger {
    public static func mergedEntries(
        birthDate: String,
        babyId: String,
        customMilestones: [CustomMilestone],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [MilestoneTimelineEntry] {
        let builtinOccurrences = MilestoneDateCalculator.occurrences(
            milestones: MilestoneCatalog.milestones,
            birthDate: birthDate,
            babyId: babyId,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let builtinEntries = builtinOccurrences.map {
            MilestoneTimelineEntry.builtin($0.milestone, triggerDate: $0.triggerDate)
        }
        let customEntries = customMilestones.map(MilestoneTimelineEntry.custom)
        return sortMerged(builtinEntries + customEntries, calendar: calendar)
    }

    public static func calendarMarkedDayKeys(
        from entries: [MilestoneTimelineEntry],
        calendar: Calendar = .current
    ) -> Set<String> {
        Set(entries.map { MilestoneDateCodec.dayKey(for: $0.triggerDate, calendar: calendar) })
    }

    public static func sortMerged(
        _ entries: [MilestoneTimelineEntry],
        calendar: Calendar = .current
    ) -> [MilestoneTimelineEntry] {
        entries.sorted { lhs, rhs in
            let lhsDay = calendar.startOfDay(for: lhs.triggerDate)
            let rhsDay = calendar.startOfDay(for: rhs.triggerDate)
            if lhsDay != rhsDay {
                return lhsDay < rhsDay
            }

            switch (lhs, rhs) {
            case let (.builtin(lhsDefinition, _), .builtin(rhsDefinition, _)):
                return lhsDefinition.sort < rhsDefinition.sort
            case (.builtin, .custom):
                return true
            case (.custom, .builtin):
                return false
            case let (.custom(lhsMilestone), .custom(rhsMilestone)):
                return lhsMilestone.name.localizedStandardCompare(rhsMilestone.name) == .orderedAscending
            }
        }
    }
}
