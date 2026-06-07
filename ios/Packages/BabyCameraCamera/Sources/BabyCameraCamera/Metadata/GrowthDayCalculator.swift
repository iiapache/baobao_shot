import Foundation

/// 按宝宝出生日计算成长天数（1-based，与 `BabyAgeFormatter` 第 1 阶段一致）。
public enum GrowthDayCalculator {
    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// 返回拍摄日当天对应的成长天数；未出生返回 `nil`。
    public static func growthDay(
        birthDate: String,
        takenAt: Date,
        calendar: Calendar = .current
    ) -> Int? {
        guard let birth = birthDateFormatter.date(from: birthDate) else {
            return nil
        }

        let start = calendar.startOfDay(for: birth)
        let end = calendar.startOfDay(for: takenAt)

        guard start <= end else {
            return nil
        }

        let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return dayCount + 1
    }
}
