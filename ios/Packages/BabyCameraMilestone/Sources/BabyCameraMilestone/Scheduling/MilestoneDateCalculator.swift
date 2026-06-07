import Foundation

/// 基于宝宝出生日计算里程碑触发日（PRD §4.8 / BabyAgeFormatter 出生第 N 天语义）。
public enum MilestoneDateCalculator {
    public static let schedulingHorizonDays = 365
    public static let birthDateFormat = "yyyy-MM-dd"

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = birthDateFormat
        return formatter
    }()

    public struct ScheduledOccurrence: Sendable, Equatable {
        public var milestone: MilestoneDefinition
        public var triggerDate: Date
        public var notificationIdentifier: String

        public init(milestone: MilestoneDefinition, triggerDate: Date, notificationIdentifier: String) {
            self.milestone = milestone
            self.triggerDate = triggerDate
            self.notificationIdentifier = notificationIdentifier
        }
    }

    public static func parseBirthDate(_ birthDate: String) -> Date? {
        birthDateFormatter.date(from: birthDate)
    }

    /// 计算在 `[referenceDate, referenceDate + 365天]` 窗口内应预约的里程碑。
    public static func occurrences(
        milestones: [MilestoneDefinition],
        birthDate: String,
        babyId: String,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [ScheduledOccurrence] {
        guard let birth = parseBirthDate(birthDate) else { return [] }

        let referenceStart = calendar.startOfDay(for: referenceDate)
        guard let horizonEnd = calendar.date(byAdding: .day, value: schedulingHorizonDays, to: referenceStart) else {
            return []
        }

        var results: [ScheduledOccurrence] = []
        var seenIdentifiers = Set<String>()

        for milestone in milestones {
            let candidates = triggerDates(
                for: milestone,
                birthDate: birth,
                referenceStart: referenceStart,
                horizonEnd: horizonEnd,
                calendar: calendar
            )

            for (triggerDate, yearSuffix) in candidates {
                let identifier = MilestoneNotificationIdentifier.make(
                    babyId: babyId,
                    milestoneId: milestone.id,
                    yearSuffix: yearSuffix
                )
                guard !seenIdentifiers.contains(identifier) else { continue }
                guard triggerDate > referenceStart, triggerDate <= horizonEnd else { continue }

                seenIdentifiers.insert(identifier)
                results.append(ScheduledOccurrence(
                    milestone: milestone,
                    triggerDate: triggerDate,
                    notificationIdentifier: identifier
                ))
            }
        }

        return results.sorted { $0.triggerDate < $1.triggerDate }
    }

    /// 出生第 N 天触发日：出生日 00:00 + (N - 1) 天。
    public static func dayOffsetTriggerDate(
        birthDate: Date,
        dayOffset: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard dayOffset >= 1 else { return nil }
        let birthStart = calendar.startOfDay(for: birthDate)
        return calendar.date(byAdding: .day, value: dayOffset - 1, to: birthStart)
    }

    // MARK: - Private

    private static func triggerDates(
        for milestone: MilestoneDefinition,
        birthDate: Date,
        referenceStart: Date,
        horizonEnd: Date,
        calendar: Calendar
    ) -> [(Date, Int?)] {
        switch milestone.trigger.kind {
        case .dayOffset:
            guard let day = milestone.trigger.day,
                  let date = dayOffsetTriggerDate(birthDate: birthDate, dayOffset: day, calendar: calendar) else {
                return []
            }
            return [(date, nil)]

        case .annual:
            guard let month = milestone.trigger.month, let day = milestone.trigger.day else { return [] }
            return annualOccurrences(
                month: month,
                day: day,
                referenceStart: referenceStart,
                horizonEnd: horizonEnd,
                calendar: calendar
            )

        case .birthdayAnnual:
            return birthdayAnnualOccurrences(
                birthDate: birthDate,
                referenceStart: referenceStart,
                horizonEnd: horizonEnd,
                calendar: calendar
            )
        }
    }

    private static func annualOccurrences(
        month: Int,
        day: Int,
        referenceStart: Date,
        horizonEnd: Date,
        calendar: Calendar
    ) -> [(Date, Int?)] {
        var results: [(Date, Int?)] = []
        let startYear = calendar.component(.year, from: referenceStart)
        let endYear = calendar.component(.year, from: horizonEnd)

        for year in startYear...endYear {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = calendar.date(from: components) else { continue }
            let trigger = calendar.startOfDay(for: date)
            guard trigger > referenceStart, trigger <= horizonEnd else { continue }
            results.append((trigger, year))
        }
        return results
    }

    private static func birthdayAnnualOccurrences(
        birthDate: Date,
        referenceStart: Date,
        horizonEnd: Date,
        calendar: Calendar
    ) -> [(Date, Int?)] {
        let birthComponents = calendar.dateComponents([.month, .day], from: birthDate)
        guard let month = birthComponents.month, let day = birthComponents.day else { return [] }

        let birthStart = calendar.startOfDay(for: birthDate)
        var results: [(Date, Int?)] = []
        let startYear = calendar.component(.year, from: referenceStart)
        let endYear = calendar.component(.year, from: horizonEnd)

        for year in startYear...endYear {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = calendar.date(from: components) else { continue }
            let trigger = calendar.startOfDay(for: date)
            guard trigger > birthStart else { continue }
            guard trigger > referenceStart, trigger <= horizonEnd else { continue }
            results.append((trigger, year))
        }
        return results
    }
}
