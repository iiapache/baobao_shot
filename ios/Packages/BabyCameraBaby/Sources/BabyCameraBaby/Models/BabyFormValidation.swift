import Foundation

public enum BabyFormValidation {
    public static let nameRequiredMessage = "请填写宝宝小名"
    public static let birthDateRequiredMessage = "请选择出生日期"

    public static func trimmedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func validate(name: String, birthDate: String?) -> String? {
        if trimmedName(name).isEmpty {
            return nameRequiredMessage
        }
        guard let birthDate, !birthDate.isEmpty else {
            return birthDateRequiredMessage
        }
        return nil
    }

    public static func birthDateString(from date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    public static func date(from birthDate: String) -> Date? {
        dateFormatter.date(from: birthDate)
    }

    public static func birthTimeString(from date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    public static func time(from birthTime: String) -> Date? {
        timeFormatter.date(from: birthTime)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
