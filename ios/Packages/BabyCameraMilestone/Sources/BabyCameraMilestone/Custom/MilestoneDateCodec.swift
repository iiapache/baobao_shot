import Foundation

enum MilestoneDateCodec {
    static func startOfDayTimestamp(for date: Date, calendar: Calendar = .current) -> Int64 {
        Int64(calendar.startOfDay(for: date).timeIntervalSince1970)
    }

    static func date(fromTimestamp timestamp: Int64, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: date))
    }
}
