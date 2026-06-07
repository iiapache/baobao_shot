import Foundation

enum WidgetRepresentativePhotoSelector {
    static let lookbackDays = 7

    static func select(
        photos: [WidgetSnapshotPhotoCandidate],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [WidgetSnapshotPhotoCandidate] {
        let sorted = photos.sorted { $0.takenAt > $1.takenAt }
        var selected: [WidgetSnapshotPhotoCandidate] = []

        for offset in 0..<lookbackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: referenceDate) else {
                continue
            }
            let dayStart = calendar.startOfDay(for: day)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }

            if let representative = sorted.first(where: { candidate in
                candidate.takenAt >= dayStart && candidate.takenAt < dayEnd
            }) {
                selected.append(representative)
            }
        }

        return selected
    }
}
