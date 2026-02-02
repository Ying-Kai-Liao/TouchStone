import SwiftUI

// MARK: - Day Hero Header

/// An engaging hero header for the day detail view with stats and workload ring.
/// Features:
/// - Large date display (formatted like "Friday, January 24")
/// - Today/Tomorrow badge (accent colored)
/// - Workload ring (64pt) using DayLoadIndicator
/// - Quick stats row: events count, work hours, free time
/// - Context badges for day plans (vacation, travel, etc.)
struct DayHeroHeader: View {
    let date: Date
    let stonesCount: Int
    let projects: [Project]
    let stones: [StoneEvent]
    let contexts: [DayContext]
    let activeContexts: [DayContext]

    private let calendar = Calendar.current
    private var prefs: UserPreferences { UserPreferences.shared }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Date title
            Text(formattedDate)
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            // Today/Tomorrow badge
            if let dayBadgeText = dayBadgeText {
                Text(dayBadgeText.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.background)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.accent)
                    .clipShape(Capsule())
            }

            // Workload ring
            DayLoadIndicator(loadPercentage: loadResult.load, size: 64)
                .padding(.vertical, DesignSystem.Spacing.sm)

            // Quick stats row
            quickStatsRow

            // Context badges
            if !activeContexts.isEmpty {
                contextBadgesRow
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    // MARK: - Computed Properties

    /// Formatted date string (e.g., "Friday, January 24")
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    /// Badge text for today/tomorrow
    private var dayBadgeText: String? {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        return nil
    }

    /// Load result from PressureCalculator
    private var loadResult: PressureCalculator.DayLoadResult {
        PressureCalculator.calculateDayLoadDetailed(
            for: date,
            projects: projects,
            stones: stones,
            contexts: contexts
        )
    }

    /// Total work hours from project allocations
    private var workHours: Double {
        let totalMinutes = loadResult.projectAllocations.reduce(0.0) { sum, allocation in
            sum + allocation.allocatedMinutes
        }
        return totalMinutes / 60.0
    }

    /// Free time in hours
    private var freeHours: Double {
        let freeMinutes = max(0, loadResult.availableMinutes - Int(workHours * 60))
        return Double(freeMinutes) / 60.0
    }

    // MARK: - Quick Stats Row

    private var quickStatsRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Events count
            statItem(
                value: stonesCount,
                label: stonesCount == 1 ? "event" : "events"
            )

            statDivider

            // Work hours
            statItem(
                value: formatHours(workHours),
                label: "work"
            )

            statDivider

            // Free time
            statItem(
                value: formatHours(freeHours),
                label: "free"
            )
        }
        .font(DesignSystem.Typography.caption)
        .foregroundStyle(DesignSystem.Colors.textSecondary)
    }

    private func statItem(value: Int, label: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text("\(value)")
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(label)
        }
    }

    private func statItem(value: String, label: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(label)
        }
    }

    private var statDivider: some View {
        Text("\u{00B7}")
            .fontWeight(.bold)
            .foregroundStyle(DesignSystem.Colors.textTertiary)
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 0.1 {
            return "0h"
        } else if hours == floor(hours) {
            return "\(Int(hours))h"
        } else {
            return String(format: "%.1fh", hours)
        }
    }

    // MARK: - Context Badges Row

    private var contextBadgesRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(activeContexts) { context in
                contextBadge(for: context)
            }
        }
    }

    private func contextBadge(for context: DayContext) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: context.type.icon)
                .font(.system(size: 10))
            Text(context.name)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(DesignSystem.Colors.accent)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.accent.opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: DesignSystem.Spacing.xl) {
            DayHeroHeader(
                date: Date(),
                stonesCount: 3,
                projects: [],
                stones: [],
                contexts: [],
                activeContexts: []
            )

            Divider()

            DayHeroHeader(
                date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                stonesCount: 1,
                projects: [],
                stones: [],
                contexts: [],
                activeContexts: []
            )
        }
        .padding(DesignSystem.Spacing.xl)
    }
    .background(DesignSystem.Colors.background)
}
