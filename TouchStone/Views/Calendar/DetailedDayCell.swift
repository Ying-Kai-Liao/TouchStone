import SwiftUI

/// Detailed calendar cell showing events and sessions inline.
/// Used when calendarDetailMode is enabled.
struct DetailedDayCell: View {
    let dayData: DayData
    let stones: [StoneEvent]
    let suggestedSessions: [SuggestedSession]
    let hasDeadline: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    /// Combined items for display (stones and sessions)
    private var displayItems: [DetailedCellItem] {
        var items: [DetailedCellItem] = []

        // Add stones with their times
        for stone in stones {
            items.append(DetailedCellItem(
                id: stone.id.uuidString,
                title: stone.title,
                timeString: stone.startTimeString,
                isStone: true
            ))
        }

        // Add suggested sessions (project names)
        for session in suggestedSessions {
            items.append(DetailedCellItem(
                id: session.id.uuidString,
                title: session.project.title,
                timeString: nil,
                isStone: false
            ))
        }

        // Sort stones first (they have times), then sessions
        return items.sorted { item1, item2 in
            if item1.isStone && !item2.isStone { return true }
            if !item1.isStone && item2.isStone { return false }
            return false
        }
    }

    private var visibleItems: [DetailedCellItem] {
        Array(displayItems.prefix(3))
    }

    private var overflowCount: Int {
        max(0, displayItems.count - 3)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                if let day = dayData.day {
                    // Top row: day number and deadline badge
                    HStack(spacing: 4) {
                        Text("\(day)")
                            .font(.system(size: 12, weight: isToday ? .bold : .medium))
                            .foregroundColor(dayData.isCurrentMonth ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(isToday ? DesignSystem.Colors.accent.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(isToday ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1.5)
                            )

                        Spacer()

                        if hasDeadline {
                            Text("DUE")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(DesignSystem.Colors.background)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.accent)
                                )
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                    // Events list
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(visibleItems) { item in
                            DetailedCellItemRow(item: item)
                        }

                        // Overflow indicator
                        if overflowCount > 0 {
                            Text("+\(overflowCount) more")
                                .font(.system(size: 8))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .padding(.leading, 2)
                        }
                    }
                    .padding(.horizontal, 2)

                    Spacer(minLength: 0)
                } else {
                    Color.clear
                        .frame(height: 100)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(cellBackgroundColor)
            )
        }
        .buttonStyle(.plain)
    }

    private var cellBackgroundColor: Color {
        if !dayData.isCurrentMonth {
            return Color.clear
        }
        // Use subtle background in detailed mode
        return DesignSystem.Colors.cardBackground
    }

    private var isToday: Bool {
        guard dayData.isCurrentMonth else { return false }
        return calendar.isDateInToday(dayData.date)
    }
}

// MARK: - Supporting Types

struct DetailedCellItem: Identifiable {
    let id: String
    let title: String
    let timeString: String?
    let isStone: Bool
}

struct DetailedCellItemRow: View {
    let item: DetailedCellItem

    var body: some View {
        HStack(spacing: 2) {
            if item.isStone {
                // Stone: show time
                if let time = item.timeString {
                    Text(time)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: 28, alignment: .leading)
                }
                Text(item.title)
                    .font(.system(size: 8))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
            } else {
                // Session: show bullet and project name
                Text("\u{2022}")
                    .font(.system(size: 8))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text(item.title)
                    .font(.system(size: 8))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    DetailedDayCell(
        dayData: DayData(date: Date(), day: 15, isCurrentMonth: true),
        stones: [],
        suggestedSessions: [],
        hasDeadline: false,
        onTap: {}
    )
    .frame(width: 50)
}
