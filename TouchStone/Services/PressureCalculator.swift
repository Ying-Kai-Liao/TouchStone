import Foundation
import SwiftUI

// MARK: - Pressure Calculator

/// Calculates aggregate pressure for calendar visualization.
/// Determines the worst-case feasibility status for any given day
/// based on all active projects with deadlines.
struct PressureCalculator {

    /// Calculate the worst feasibility status for a given day
    /// Takes the maximum pressure from all projects that have deadlines on or after this day
    static func aggregateFeasibility(for date: Date, projects: [Project]) -> FeasibilityStatus {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        var worstStatus: FeasibilityStatus = .noDeadline

        for project in projects where project.isActive {
            guard let deadline = project.softDeadline else { continue }

            // Only consider projects whose deadline is on or after this date
            let deadlineStart = calendar.startOfDay(for: deadline)
            guard deadlineStart >= dayStart else {
                // Deadline already passed - if viewing today, show overdue
                if calendar.isDate(dayStart, inSameDayAs: Date()) {
                    if worstStatus.severity < FeasibilityStatus.overdue.severity {
                        worstStatus = .overdue
                    }
                }
                continue
            }

            // Calculate pressure as if "today" were this date
            let daysRemaining = calendar.dateComponents([.day], from: dayStart, to: deadlineStart).day ?? 0
            let remainingHours = project.remainingHours

            let status: FeasibilityStatus
            if daysRemaining <= 0 {
                // Deadline is today
                status = remainingHours > 0 ? .impossible : .healthy
            } else {
                let requiredDaily = Double(remainingHours) / Double(daysRemaining)
                let capacity = Double(UserPreferences.shared.dailyProductiveHours)
                let ratio = requiredDaily / capacity

                switch ratio {
                case ...0.5: status = .healthy
                case 0.5...0.8: status = .tight
                case 0.8...1.0: status = .atRisk
                default: status = .impossible
                }
            }

            // Keep the worst status
            if status.severity > worstStatus.severity {
                worstStatus = status
            }
        }

        return worstStatus
    }

    /// Check if any project has a deadline on a specific day
    static func hasDeadline(on date: Date, projects: [Project]) -> Bool {
        let calendar = Calendar.current
        return projects.contains { project in
            guard let deadline = project.softDeadline else { return false }
            return calendar.isDate(deadline, inSameDayAs: date)
        }
    }

    /// Get the projects that have deadlines on a specific day
    static func projectsWithDeadline(on date: Date, projects: [Project]) -> [Project] {
        let calendar = Calendar.current
        return projects.filter { project in
            guard let deadline = project.softDeadline else { return false }
            return calendar.isDate(deadline, inSameDayAs: date)
        }
    }
}
