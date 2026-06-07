import Foundation

/// Formats baby age per PRD §4.2.3 — day / month+day / year+month / year+date display rules.
public enum BabyAgeFormatter {
    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let referenceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    public static func displayAge(birthDate: String, referenceDate: Date = Date()) -> String {
        guard let birth = birthDateFormatter.date(from: birthDate) else {
            return birthDate
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: birth)
        let end = calendar.startOfDay(for: referenceDate)

        guard start <= end else {
            return "未出生"
        }

        let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let ageDay = dayCount + 1

        // Phase 1: 出生 0–99 天 → 「出生第 N 天」
        if ageDay <= 99 {
            return "出生第 \(ageDay) 天"
        }

        let components = calendar.dateComponents([.year, .month, .day], from: start, to: end)
        let years = components.year ?? 0
        let months = components.month ?? 0
        let days = components.day ?? 0

        // Phase 4: 3 岁以上 → 「N 岁」+ 当天日期
        if years >= 3 {
            let dateText = referenceDateFormatter.string(from: end)
            return "\(years) 岁 \(dateText)"
        }

        // Phase 3: 1 岁 – 3 岁 → 「N 岁 N 个月」
        if years >= 1 {
            return months > 0 ? "\(years) 岁 \(months) 个月" : "\(years) 岁"
        }

        // Phase 2: 100–365 天 → 「N 个月 N 天」
        if months > 0 && days > 0 {
            return "\(months) 个月 \(days) 天"
        }
        if months > 0 {
            return "\(months) 个月"
        }
        return "\(days) 天"
    }
}
