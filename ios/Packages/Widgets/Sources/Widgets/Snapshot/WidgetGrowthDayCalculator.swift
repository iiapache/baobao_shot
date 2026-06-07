import Foundation

enum WidgetGrowthDayCalculator {
    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func growthDay(
        birthDate: String,
        referenceDate: Date,
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

    static func dayString(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return birthDateFormatter.string(from: date)
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
