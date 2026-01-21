import WidgetKit
import SwiftUI

// MARK: - Lock Screen Widget (iOS 16+)

@available(iOS 16.0, *)
struct TouchStoneLockScreenWidget: Widget {
    let kind: String = "TouchStoneLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TouchStoneProvider()) { entry in
            TouchStoneLockScreenView(entry: entry)
        }
        .configurationDisplayName("Status")
        .description("Quick status on your lock screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Lock Screen View

@available(iOS 16.0, *)
struct TouchStoneLockScreenView: View {
    let entry: TouchStoneEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryInline:
            InlineView(entry: entry)
        default:
            InlineView(entry: entry)
        }
    }
}

// MARK: - Circular View (Touch Progress Ring)

@available(iOS 16.0, *)
struct CircularView: View {
    let entry: TouchStoneEntry

    var body: some View {
        Gauge(value: entry.widgetData.todayStats.progress) {
            Image(systemName: "hand.tap.fill")
        } currentValueLabel: {
            Text("\(entry.widgetData.todayStats.touchCount)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Rectangular View (Status + Suggestion)

@available(iOS 16.0, *)
struct RectangularView: View {
    let entry: TouchStoneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Status line
            HStack(spacing: 4) {
                Image(systemName: statusIcon)
                    .font(.caption2)
                Text(statusText)
                    .font(.headline)
                    .lineLimit(1)
            }

            // Suggestion or next event
            if !entry.widgetData.currentStatus.isInStone {
                if let project = entry.widgetData.suggestedProject {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text(project.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                } else if let next = entry.widgetData.nextStone {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("\(next.title) \(next.timeUntil)")
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
            } else if let next = entry.widgetData.nextStone {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text("Then: \(next.title)")
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var statusIcon: String {
        entry.widgetData.currentStatus.isInStone ? "square.fill" : "checkmark.circle"
    }

    var statusText: String {
        switch entry.widgetData.currentStatus {
        case .inStone(let stone):
            return stone.title
        case .free(until: let date):
            if let date = date {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Free til \(formatter.string(from: date))"
            }
            return "Free"
        }
    }
}

// MARK: - Inline View (Compact Status)

@available(iOS 16.0, *)
struct InlineView: View {
    let entry: TouchStoneEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)

            Text(statusText)
        }
    }

    var statusIcon: String {
        entry.widgetData.currentStatus.isInStone ? "square.fill" : "hand.tap.fill"
    }

    var statusText: String {
        if entry.widgetData.currentStatus.isInStone {
            if case .inStone(let stone) = entry.widgetData.currentStatus {
                return stone.title
            }
            return "Busy"
        }

        if let project = entry.widgetData.suggestedProject {
            return "Work on \(project.title)"
        }

        return "\(entry.widgetData.todayStats.touchCount) touches today"
    }
}

// MARK: - Preview

@available(iOS 16.0, *)
#Preview("Circular", as: .accessoryCircular) {
    TouchStoneLockScreenWidget()
} timeline: {
    TouchStoneEntry.placeholder
}

@available(iOS 16.0, *)
#Preview("Rectangular", as: .accessoryRectangular) {
    TouchStoneLockScreenWidget()
} timeline: {
    TouchStoneEntry.placeholder
}

@available(iOS 16.0, *)
#Preview("Inline", as: .accessoryInline) {
    TouchStoneLockScreenWidget()
} timeline: {
    TouchStoneEntry.placeholder
}
