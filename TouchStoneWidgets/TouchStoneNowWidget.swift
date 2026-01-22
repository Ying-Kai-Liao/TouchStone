import WidgetKit
import SwiftUI

// MARK: - Now Widget (Medium Size - Contextual Now)

struct TouchStoneNowWidget: Widget {
    let kind: String = "TouchStoneNowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TouchStoneProvider()) { entry in
            TouchStoneNowWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("What Now")
        .description("See your current status and what to work on next.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Now Widget View

struct TouchStoneNowWidgetView: View {
    let entry: TouchStoneEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallNowView(entry: entry)
        case .systemMedium:
            MediumNowView(entry: entry)
        default:
            MediumNowView(entry: entry)
        }
    }
}

// MARK: - Small Now View

struct SmallNowView: View {
    let entry: TouchStoneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            // Main content
            if entry.widgetData.currentStatus.isInStone {
                // In a stone
                if case .inStone(let stone) = entry.widgetData.currentStatus {
                    Text(stone.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    Spacer()

                    if let next = entry.widgetData.nextStone {
                        Text("Next: \(next.title)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                // Free time
                if let project = entry.widgetData.suggestedProject {
                    Text(project.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    Spacer()

                    if let staleness = project.stalenessText {
                        Text(staleness)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("Free Time")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("No projects")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats row
            HStack {
                Image(systemName: "hand.tap.fill")
                    .font(.caption2)
                Text("\(entry.widgetData.todayStats.touchCount)")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                if let next = entry.widgetData.nextStone, !entry.widgetData.currentStatus.isInStone {
                    Text(next.timeUntil)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(2)
    }

    var statusColor: Color {
        entry.widgetData.currentStatus.isInStone ? .orange : .green
    }

    var statusLabel: String {
        entry.widgetData.currentStatus.isInStone ? "BUSY" : "FREE"
    }
}

// MARK: - Medium Now View (Contextual Now)

struct MediumNowView: View {
    let entry: TouchStoneEntry

    var body: some View {
        HStack(spacing: 12) {
            // Left side: Date
            VStack(alignment: .center, spacing: 2) {
                Text(dayOfWeek)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(dayNumber)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(monthName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)

            Divider()
                .frame(height: 60)

            // Right side: Status & Suggestion
            VStack(alignment: .leading, spacing: 6) {
                // Current status
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                // Suggestion or next stone
                if entry.widgetData.currentStatus.isInStone {
                    if let next = entry.widgetData.nextStone {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                            Text("Next: \(next.title) \(next.timeUntil)")
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                    }
                } else if let project = entry.widgetData.suggestedProject {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Consider:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(project.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 8) {
                            if project.hasProgress {
                                Text(project.progressText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if let staleness = project.stalenessText {
                                Text(staleness)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }

                            if let days = project.daysUntilDeadline, days <= 7 {
                                Text("\(days)d left")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                Spacer()

                // Bottom stats
                HStack(spacing: 12) {
                    Label("\(entry.widgetData.todayStats.touchCount) touches", systemImage: "hand.tap.fill")
                    Label("\(entry.widgetData.todayStats.stonesCount) stones", systemImage: "square.fill")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(4)
    }

    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: entry.date).uppercased()
    }

    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: entry.date)
    }

    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: entry.date)
    }

    var statusColor: Color {
        entry.widgetData.currentStatus.isInStone ? .orange : .green
    }

    var statusText: String {
        switch entry.widgetData.currentStatus {
        case .inStone(let stone):
            return stone.title
        case .free(until: let date):
            if let date = date {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Free until \(formatter.string(from: date))"
            }
            return "Free time"
        }
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    TouchStoneNowWidget()
} timeline: {
    TouchStoneEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    TouchStoneNowWidget()
} timeline: {
    TouchStoneEntry.placeholder
}
