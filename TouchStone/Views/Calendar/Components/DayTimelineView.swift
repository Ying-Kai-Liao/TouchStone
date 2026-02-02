import SwiftUI

// MARK: - Day Timeline View

/// Visual timeline with hour grid showing positioned event blocks.
/// Events are positioned vertically based on start time.
/// Overlapping events are arranged side-by-side (Google Calendar style).
struct DayTimelineView: View {
    let date: Date
    let stones: [StoneEvent]
    let suggestedSessions: [SuggestedSession]
    let onStoneEdit: (StoneEvent) -> Void
    let onStoneDelete: (StoneEvent) -> Void

    // Animation state for staggered entry
    @State private var eventsAppeared = false

    // Timeline constants
    private let startHour: Int = 6   // 6 AM
    private let endHour: Int = 22    // 10 PM
    private let hourHeight: CGFloat = 60
    private let timeColumnWidth: CGFloat = 50
    private let minEventWidth: CGFloat = 80
    private let maxOverlapColumns: Int = 3

    private var totalHours: Int { endHour - startHour }
    private var timelineHeight: CGFloat { CGFloat(totalHours) * hourHeight }

    private let calendar = Calendar.current

    // Combined timeline items from stones and suggested sessions
    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []

        // Add stones that occur on this date
        for stone in stones where stone.occursOn(date: date) {
            items.append(TimelineItem(
                id: stone.id,
                startHour: stone.startHour,
                startMinute: stone.startMinute,
                endHour: stone.endHour,
                endMinute: stone.endMinute,
                variant: .stone(stone)
            ))
        }

        // Add suggested sessions
        for session in suggestedSessions {
            let startComponents = calendar.dateComponents([.hour, .minute], from: session.timeSlot.start)
            let endComponents = calendar.dateComponents([.hour, .minute], from: session.timeSlot.end)

            if let startHour = startComponents.hour,
               let startMinute = startComponents.minute,
               let endHour = endComponents.hour,
               let endMinute = endComponents.minute {
                items.append(TimelineItem(
                    id: session.id,
                    startHour: startHour,
                    startMinute: startMinute,
                    endHour: endHour,
                    endMinute: endMinute,
                    variant: .water(session)
                ))
            }
        }

        return items.sorted { $0.startMinutes < $1.startMinutes }
    }

    // Check if viewing today
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    // Current time position (0 to 1) within the timeline
    private var currentTimeProgress: CGFloat? {
        guard isToday else { return nil }
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        guard hour >= startHour && hour < endHour else { return nil }

        let minutesSinceStart = (hour - startHour) * 60 + minute
        let totalMinutes = totalHours * 60
        return CGFloat(minutesSinceStart) / CGFloat(totalMinutes)
    }

    var body: some View {
        GeometryReader { geometry in
            let eventAreaWidth = geometry.size.width - timeColumnWidth - DesignSystem.Spacing.sm

            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Hour grid lines and labels
                    hourGrid

                    // Positioned events
                    positionedEvents(eventAreaWidth: eventAreaWidth)

                    // Current time indicator (red line)
                    if let progress = currentTimeProgress {
                        currentTimeIndicator(progress: progress, width: geometry.size.width)
                    }
                }
                .frame(height: timelineHeight)
            }
            .onAppear {
                // Trigger staggered entry animation
                eventsAppeared = true
            }
        }
    }

    // MARK: - Hour Grid

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    // Time label
                    Text(formatHour(hour))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: timeColumnWidth, alignment: .trailing)
                        .padding(.trailing, DesignSystem.Spacing.sm)
                        .offset(y: -6) // Align with grid line

                    // Grid line
                    Rectangle()
                        .fill(DesignSystem.Colors.divider)
                        .frame(height: 1)
                }
                .frame(height: hourHeight)
            }
        }
    }

    // MARK: - Positioned Events

    private func positionedEvents(eventAreaWidth: CGFloat) -> some View {
        let layoutItems = calculateLayout(items: timelineItems, availableWidth: eventAreaWidth)

        return ForEach(Array(layoutItems.enumerated()), id: \.element.item.id) { index, layoutItem in
            DayTimelineEventCard(
                variant: layoutItem.item.variant,
                isCompact: layoutItem.isCompact,
                onTap: {
                    handleTap(layoutItem.item)
                }
            )
            .frame(width: layoutItem.width, height: layoutItem.height)
            .position(
                x: timeColumnWidth + DesignSystem.Spacing.sm + layoutItem.x + layoutItem.width / 2,
                y: layoutItem.y + layoutItem.height / 2
            )
            // Staggered entry animation
            .opacity(eventsAppeared ? 1 : 0)
            .offset(y: eventsAppeared ? 0 : 10)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.8).delay(Double(index) * 0.05),
                value: eventsAppeared
            )
        }
    }

    // MARK: - Current Time Indicator

    private func currentTimeIndicator(progress: CGFloat, width: CGFloat) -> some View {
        let yPosition = progress * timelineHeight

        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: timeColumnWidth - 4)

            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
        }
        .position(x: width / 2, y: yPosition)
    }

    // MARK: - Layout Algorithm

    private func calculateLayout(items: [TimelineItem], availableWidth: CGFloat) -> [LayoutItem] {
        guard !items.isEmpty else { return [] }

        // Group overlapping items
        let conflictGroups = groupByTimeConflict(items)

        var layoutItems: [LayoutItem] = []

        for group in conflictGroups {
            if group.count == 1 {
                // Single item - full width
                let item = group[0]
                let layout = createLayoutItem(item: item, column: 0, totalColumns: 1, availableWidth: availableWidth)
                layoutItems.append(layout)
            } else {
                // Multiple overlapping items - assign columns
                let columns = assignColumns(group)
                let totalColumns = min(columns.max()! + 1, maxOverlapColumns)

                for (item, column) in zip(group, columns) {
                    let layout = createLayoutItem(
                        item: item,
                        column: min(column, totalColumns - 1),
                        totalColumns: totalColumns,
                        availableWidth: availableWidth
                    )
                    layoutItems.append(layout)
                }
            }
        }

        return layoutItems
    }

    private func groupByTimeConflict(_ items: [TimelineItem]) -> [[TimelineItem]] {
        guard !items.isEmpty else { return [] }

        var groups: [[TimelineItem]] = []
        var currentGroup: [TimelineItem] = [items[0]]
        var groupEndMinutes = items[0].endMinutes

        for item in items.dropFirst() {
            if item.startMinutes < groupEndMinutes {
                // Overlaps with current group
                currentGroup.append(item)
                groupEndMinutes = max(groupEndMinutes, item.endMinutes)
            } else {
                // Start new group
                groups.append(currentGroup)
                currentGroup = [item]
                groupEndMinutes = item.endMinutes
            }
        }

        groups.append(currentGroup)
        return groups
    }

    private func assignColumns(_ items: [TimelineItem]) -> [Int] {
        // Sort by start time, then by duration (longer first)
        let sorted = items.sorted { lhs, rhs in
            if lhs.startMinutes != rhs.startMinutes {
                return lhs.startMinutes < rhs.startMinutes
            }
            return lhs.durationMinutes > rhs.durationMinutes
        }

        var columns: [Int] = Array(repeating: 0, count: items.count)
        var columnEndTimes: [Int] = []

        for item in sorted {
            // Find original index
            let originalIndex = items.firstIndex(where: { $0.id == item.id })!

            // Find first available column
            var assignedColumn = 0
            for (colIndex, endTime) in columnEndTimes.enumerated() {
                if item.startMinutes >= endTime {
                    assignedColumn = colIndex
                    columnEndTimes[colIndex] = item.endMinutes
                    break
                }
                assignedColumn = colIndex + 1
            }

            if assignedColumn >= columnEndTimes.count {
                columnEndTimes.append(item.endMinutes)
            }

            columns[originalIndex] = min(assignedColumn, maxOverlapColumns - 1)
        }

        return columns
    }

    private func createLayoutItem(item: TimelineItem, column: Int, totalColumns: Int, availableWidth: CGFloat) -> LayoutItem {
        let columnWidth = max(minEventWidth, availableWidth / CGFloat(totalColumns))
        let x = CGFloat(column) * columnWidth

        let startOffset = CGFloat(item.startMinutes - startHour * 60) / 60.0 * hourHeight
        let height = max(20, CGFloat(item.durationMinutes) / 60.0 * hourHeight - 2)

        let isCompact = height < 40

        return LayoutItem(
            item: item,
            x: x,
            y: startOffset,
            width: columnWidth - 2,
            height: height,
            isCompact: isCompact
        )
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let period = hour >= 12 ? "PM" : "AM"
        return "\(displayHour) \(period)"
    }

    private func handleTap(_ item: TimelineItem) {
        switch item.variant {
        case .stone(let stone):
            onStoneEdit(stone)
        case .water:
            // Suggested sessions currently don't have tap action in DayDetailView
            break
        }
    }
}

// MARK: - Timeline Item

private struct TimelineItem: Identifiable {
    let id: UUID
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let variant: DayTimelineEventCard.CardVariant

    var startMinutes: Int { startHour * 60 + startMinute }
    var endMinutes: Int { endHour * 60 + endMinute }
    var durationMinutes: Int { endMinutes - startMinutes }
}

// MARK: - Layout Item

private struct LayoutItem {
    let item: TimelineItem
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let isCompact: Bool
}

#Preview {
    DayTimelineView(
        date: Date(),
        stones: [
            StoneEvent(title: "Morning Meeting", startHour: 8, startMinute: 0, endHour: 9, endMinute: 30, specificDate: Date()),
            StoneEvent(title: "Lunch", startHour: 12, startMinute: 0, endHour: 13, endMinute: 0, specificDate: Date()),
            StoneEvent(title: "Call", startHour: 10, startMinute: 0, endHour: 10, endMinute: 30, specificDate: Date()),
            StoneEvent(title: "Review", startHour: 10, startMinute: 0, endHour: 11, endMinute: 30, specificDate: Date())
        ],
        suggestedSessions: [],
        onStoneEdit: { _ in },
        onStoneDelete: { _ in }
    )
    .frame(height: 600)
    .padding()
    .background(DesignSystem.Colors.background)
}
