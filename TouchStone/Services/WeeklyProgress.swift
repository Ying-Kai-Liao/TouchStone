import Foundation
import SwiftData

// MARK: - Weekly Progress Service

/// Tracks weekly targets and progress per project for deadline-aware scheduling.
/// Used by DayState to calculate priority scores based on weekly catchup needs.
struct WeeklyProgress {
    let weekStart: Date
    let weekEnd: Date
    let calendar = Calendar.current

    /// Progress tracking for a single project within the week
    struct ProjectProgress {
        let projectId: UUID
        let targetHoursThisWeek: Double     // Derived from deadline or capacity
        let completedHoursThisWeek: Double  // From TouchLogs this week
        let missedFromPreviousDays: Double  // Behind schedule amount

        /// Whether project is within 80% of expected progress for the week
        var isOnTrack: Bool {
            guard targetHoursThisWeek > 0 else { return true }
            return completedHoursThisWeek >= targetHoursThisWeek * 0.8
        }

        /// How far behind (negative) or ahead (positive) of target
        var weeklyDelta: Double {
            completedHoursThisWeek - targetHoursThisWeek
        }
    }

    // MARK: - Initialization

    init(for date: Date = Date()) {
        let calendar = Calendar.current
        // Get the start of the week (Monday or Sunday based on locale)
        let weekday = calendar.component(.weekday, from: date)
        let daysToSubtract = (weekday == 1) ? 6 : weekday - 2  // Adjust for Monday start
        self.weekStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? date)
        self.weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? date
    }

    // MARK: - Progress Calculation

    /// Calculate weekly progress for a project
    func calculateProgress(for project: Project, dailyCapacity: Int, date: Date = Date()) -> ProjectProgress {
        // Calculate completed hours this week
        let completedHours = calculateCompletedHoursThisWeek(for: project)

        // Calculate target hours for this week
        let targetHours = calculateTargetHoursThisWeek(
            for: project,
            dailyCapacity: dailyCapacity,
            fromDate: date
        )

        // Calculate missed hours (expected progress so far - actual)
        let daysPassed = daysSinceWeekStart(from: date)
        let expectedSoFar = (targetHours / 7.0) * Double(daysPassed)
        let missed = max(0, expectedSoFar - completedHours)

        return ProjectProgress(
            projectId: project.id,
            targetHoursThisWeek: targetHours,
            completedHoursThisWeek: completedHours,
            missedFromPreviousDays: missed
        )
    }

    /// Calculate completed hours for a project this week
    private func calculateCompletedHoursThisWeek(for project: Project) -> Double {
        let weekLogs = project.touchLogs.filter { log in
            log.timestamp >= weekStart && log.timestamp < weekEnd
        }
        let totalMinutes = weekLogs.reduce(0) { $0 + $1.durationMinutes }
        return Double(totalMinutes) / 60.0
    }

    /// Calculate target hours for this week based on deadline or balanced share
    private func calculateTargetHoursThisWeek(for project: Project, dailyCapacity: Int, fromDate: Date) -> Double {
        let weeklyCapacity = Double(dailyCapacity * 7)

        // If project has a deadline, calculate based on required pace
        if let deadline = project.deadline {
            let weeksUntilDeadline = weeksUntil(deadline: deadline, from: fromDate)

            if weeksUntilDeadline <= 0 {
                // Past deadline or due this week - need all remaining hours
                return Double(project.remainingHours)
            }

            // Distribute remaining hours across remaining weeks
            let weeklyTarget = Double(project.remainingHours) / weeksUntilDeadline

            // Cap at weekly capacity (you can't do more than capacity)
            return min(weeklyTarget, weeklyCapacity)
        }

        // No deadline: balanced share = daily capacity / 3 projects * 7 days
        // This gives each project a fair slice when there's no urgency
        return weeklyCapacity / 3.0
    }

    /// Calculate weeks until deadline (including fractional weeks)
    private func weeksUntil(deadline: Date, from date: Date) -> Double {
        let days = calendar.dateComponents([.day], from: date, to: deadline).day ?? 0
        return Double(days) / 7.0
    }

    /// Days passed since week start
    private func daysSinceWeekStart(from date: Date) -> Int {
        let days = calendar.dateComponents([.day], from: weekStart, to: date).day ?? 0
        return max(0, min(7, days + 1)) // +1 because current day counts
    }

    // MARK: - Convenience

    /// Check if a date falls within this week
    func contains(_ date: Date) -> Bool {
        date >= weekStart && date < weekEnd
    }

    /// Days remaining in the week (including today)
    func daysRemainingInWeek(from date: Date) -> Int {
        let days = calendar.dateComponents([.day], from: date, to: weekEnd).day ?? 0
        return max(0, days)
    }
}
