import Foundation
import WidgetKit
import Widgets

struct BabyWidgetEntry: TimelineEntry {
    let date: Date
    let content: BabyWidgetTimelineContent
}

struct BabyWidgetTimelineProvider: TimelineProvider {
    private let snapshotLoader: any BabyWidgetSnapshotLoading
    private let calendar: Calendar

    init(
        snapshotLoader: any BabyWidgetSnapshotLoading = BabyWidgetSnapshotLoader(),
        calendar: Calendar = .current
    ) {
        self.snapshotLoader = snapshotLoader
        self.calendar = calendar
    }

    func placeholder(in context: Context) -> BabyWidgetEntry {
        BabyWidgetEntry(
            date: Date(),
            content: BabyWidgetTimelineContentBuilder.placeholder(referenceDate: Date())
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BabyWidgetEntry) -> Void) {
        let referenceDate = Date()
        let plan = makePlan(referenceDate: referenceDate, isPreview: context.isPreview)
        completion(BabyWidgetEntry(date: plan.content.date, content: plan.content))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyWidgetEntry>) -> Void) {
        let referenceDate = Date()
        let plan = makePlan(referenceDate: referenceDate, isPreview: context.isPreview)
        let entry = BabyWidgetEntry(date: plan.content.date, content: plan.content)
        let timeline = Timeline(entries: [entry], policy: .after(plan.nextRefreshDate))
        completion(timeline)
    }

    private func makePlan(referenceDate: Date, isPreview: Bool) -> BabyWidgetTimelinePlan {
        if isPreview {
            return BabyWidgetTimelinePlan(
                content: BabyWidgetTimelineContentBuilder.placeholder(referenceDate: referenceDate),
                nextRefreshDate: BabyWidgetTimelineContentBuilder.nextRefreshDate(
                    after: referenceDate,
                    calendar: calendar
                )
            )
        }

        let snapshot = try? snapshotLoader.loadSnapshot()
        return BabyWidgetTimelineContentBuilder.build(
            from: snapshot,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }
}
