import WidgetKit
import SwiftUI

// MARK: - Date Widget (Small Size - Today Card)

struct TouchStoneDateWidget: Widget {
    let kind: String = "TouchStoneDateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TouchStoneProvider()) { entry in
            TouchStoneDateWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Today's date with current activity.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Date Widget View

struct TouchStoneDateWidgetView: View {
    let entry: TouchStoneEntry

    var body: some View {
        VStack(spacing: 8) {
            // Date section
            VStack(spacing: 0) {
                Text(dayOfWeek)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)

                Text(dayNumber)
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .foregroundStyle(.primary)

                Text(monthName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.horizontal, 16)

            // Current activity
            VStack(spacing: 2) {
                if entry.widgetData.currentStatus.isInStone {
                    if case .inStone(let stone) = entry.widgetData.currentStatus {
                        Text(stone.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        Text("now")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                } else {
                    if let next = entry.widgetData.nextStone {
                        Text(next.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        Text(next.timeString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No events")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(4)
    }

    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
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
}

// MARK: - Preview

#Preview("Date Widget", as: .systemSmall) {
    TouchStoneDateWidget()
} timeline: {
    TouchStoneEntry.placeholder
}
