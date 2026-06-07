import SwiftUI

public struct MilestoneCalendarView: View {
    public let markedDayKeys: Set<String>
    public let selectedDayKey: String?
    public let onSelectDay: (String) -> Void

    private let calendar: Calendar
    private let monthAnchor: Date

    public init(
        markedDayKeys: Set<String>,
        selectedDayKey: String? = nil,
        monthAnchor: Date = Date(),
        calendar: Calendar = .current,
        onSelectDay: @escaping (String) -> Void
    ) {
        self.markedDayKeys = markedDayKeys
        self.selectedDayKey = selectedDayKey
        self.monthAnchor = monthAnchor
        self.calendar = calendar
        self.onSelectDay = onSelectDay
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthTitle)
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(dayCells, id: \.dayKey) { cell in
                    if cell.isPlaceholder {
                        Color.clear.frame(height: 32)
                    } else {
                        Button {
                            onSelectDay(cell.dayKey)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(backgroundColor(for: cell))
                                    .frame(width: 32, height: 32)
                                Text("\(cell.dayNumber)")
                                    .font(.caption)
                                    .foregroundStyle(foregroundColor(for: cell))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("milestoneCalendarDay.\(cell.dayKey)")
                    }
                }
            }
        }
        .accessibilityIdentifier("milestoneCalendarView")
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: monthAnchor)
    }

    private var weekdaySymbols: [String] {
        ["日", "一", "二", "三", "四", "五", "六"]
    }

    private struct DayCell {
        var dayKey: String
        var dayNumber: Int
        var isPlaceholder: Bool
        var isMarked: Bool
        var isSelected: Bool
    }

    private var dayCells: [DayCell] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthAnchor),
              let dayRange = calendar.range(of: .day, in: .month, for: monthAnchor) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingPlaceholders = firstWeekday - 1

        var cells: [DayCell] = (0..<leadingPlaceholders).map { index in
            DayCell(dayKey: "placeholder-\(index)", dayNumber: 0, isPlaceholder: true, isMarked: false, isSelected: false)
        }

        for day in dayRange {
            var components = calendar.dateComponents([.year, .month], from: monthAnchor)
            components.day = day
            guard let date = calendar.date(from: components) else { continue }
            let dayKey = MilestoneDateCodec.dayKey(for: date, calendar: calendar)
            cells.append(
                DayCell(
                    dayKey: dayKey,
                    dayNumber: day,
                    isPlaceholder: false,
                    isMarked: markedDayKeys.contains(dayKey),
                    isSelected: selectedDayKey == dayKey
                )
            )
        }
        return cells
    }

    private func backgroundColor(for cell: DayCell) -> Color {
        if cell.isSelected {
            return .blue
        }
        if cell.isMarked {
            return .orange.opacity(0.25)
        }
        return .clear
    }

    private func foregroundColor(for cell: DayCell) -> Color {
        if cell.isSelected {
            return .white
        }
        if cell.isMarked {
            return .orange
        }
        return .primary
    }
}
