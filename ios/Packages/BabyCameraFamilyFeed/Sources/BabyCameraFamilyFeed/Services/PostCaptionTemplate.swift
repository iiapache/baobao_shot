import Foundation

/// 默认文案模板：「{宝宝小名} · 第 {N} 天 · {AI 玩法名}」
public enum PostCaptionTemplate {
    public static let templatePattern = "{宝宝小名} · 第 {N} 天 · {AI 玩法名}"

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public static func growthDay(
        birthDate: String,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let birth = birthDateFormatter.date(from: birthDate) else {
            return nil
        }

        let start = calendar.startOfDay(for: birth)
        let end = calendar.startOfDay(for: referenceDate)

        guard start <= end else {
            return nil
        }

        let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return dayCount + 1
    }

    public static func makeCaption(
        babyName: String,
        birthDate: String,
        aiPlayName: String?,
        referenceDate: Date = Date()
    ) -> String {
        let trimmedName = babyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "宝宝" : trimmedName

        let dayText: String
        if let day = growthDay(birthDate: birthDate, referenceDate: referenceDate) {
            dayText = "第 \(day) 天"
        } else {
            dayText = "第 ? 天"
        }

        let playName = aiPlayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let playName, !playName.isEmpty {
            return "\(name) · \(dayText) · \(playName)"
        }
        return "\(name) · \(dayText)"
    }
}
