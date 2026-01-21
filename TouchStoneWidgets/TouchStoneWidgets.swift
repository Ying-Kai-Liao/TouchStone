import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct TouchStoneWidgets: WidgetBundle {
    var body: some Widget {
        TouchStoneNowWidget()
        TouchStoneDateWidget()
        if #available(iOS 16.0, *) {
            TouchStoneLockScreenWidget()
        }
    }
}

// MARK: - Timeline Provider

struct TouchStoneProvider: TimelineProvider {
    func placeholder(in context: Context) -> TouchStoneEntry {
        TouchStoneEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TouchStoneEntry) -> Void) {
        let data = WidgetDataManager.shared.load()
        let entry = TouchStoneEntry(date: Date(), widgetData: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TouchStoneEntry>) -> Void) {
        let data = WidgetDataManager.shared.load()
        let currentDate = Date()
        let entry = TouchStoneEntry(date: currentDate, widgetData: data)

        // Update every 15 minutes or at the next stone start time
        var nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate

        // If there's a next stone, update when it starts
        if let nextStone = data.nextStone {
            let stoneStart = nextStone.startTime
            if stoneStart > currentDate && stoneStart < nextUpdate {
                nextUpdate = stoneStart
            }
        }

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct TouchStoneEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData

    static let placeholder = TouchStoneEntry(
        date: Date(),
        widgetData: WidgetData(
            date: Date(),
            currentStatus: .free(until: Calendar.current.date(byAdding: .hour, value: 2, to: Date())),
            nextStone: StoneInfo(
                id: UUID(),
                title: "Team Meeting",
                startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                endTime: Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date()
            ),
            suggestedProject: ProjectInfo(
                id: UUID(),
                title: "App Redesign",
                daysSinceTouch: 3,
                completedHours: 8,
                plannedHours: 20,
                currentPhase: "Building",
                hasDeadline: true,
                daysUntilDeadline: 5
            ),
            todayStats: TodayStats(
                touchCount: 2,
                touchedMinutes: 120,
                capacityMinutes: 360,
                stonesCount: 3
            ),
            updatedAt: Date()
        )
    )
}
