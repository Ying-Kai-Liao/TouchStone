import Foundation
import SwiftUI

// MARK: - Pressure Calculator

/// Calculates aggregate pressure for calendar visualization.
/// Based on the liquid scheduling model:
/// - Pressure = (Required Work × 1.25 buffer) / Available Capacity
/// - Available Capacity = Daily Hours - Stone (fixed event) Hours
struct PressureCalculator {

    /// Detailed pressure calculation result for a single project
    struct ProjectPressure {
        let project: Project
        let deadline: Date
        let daysRemaining: Int
        let remainingMinutes: Int
        let requiredMinutesWithBuffer: Int  // includes 25% safety buffer
        let totalCapacityMinutes: Int       // days × daily capacity
        let stoneMinutes: Int               // fixed events blocking time
        let availableCapacityMinutes: Int   // total - stones
        let pressure: Int                   // 0-100+ percentage
        let status: FeasibilityStatus
    }

    /// Daily pressure calculation result
    struct DayPressure {
        let date: Date
        let dailyCapacityMinutes: Int
        let stoneMinutes: Int
        let availableMinutes: Int
        let projectPressures: [ProjectPressure]
        let aggregateStatus: FeasibilityStatus
        let worstPressure: Int
    }

    // MARK: - Main Calculation

    /// Calculate detailed pressure for a specific day
    static func calculateDayPressure(
        for date: Date,
        projects: [Project],
        stones: [StoneEvent],
        dailyCapacityHours: Int
    ) -> DayPressure {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Calculate stone minutes for this day
        let stoneMinutes = calculateStoneMinutes(for: date, stones: stones)
        let dailyCapacityMinutes = dailyCapacityHours * 60
        let availableMinutes = max(0, dailyCapacityMinutes - stoneMinutes)

        var projectPressures: [ProjectPressure] = []
        var worstStatus: FeasibilityStatus = .noDeadline
        var worstPressure = 0

        for project in projects where project.isActive {
            guard let deadline = project.deadline else { continue }

            let deadlineStart = calendar.startOfDay(for: deadline)
            let daysRemaining = calendar.dateComponents([.day], from: dayStart, to: deadlineStart).day ?? 0

            let remainingMinutes = project.remainingHours * 60
            let requiredMinutesWithBuffer = Int(Double(remainingMinutes) * 1.25) // 25% safety buffer

            let pressure: Int
            let status: FeasibilityStatus

            if daysRemaining < 0 {
                // Deadline already passed
                pressure = remainingMinutes > 0 ? 100 : 0
                status = remainingMinutes > 0 ? .overdue : .healthy
            } else if daysRemaining == 0 {
                // Deadline is today
                if availableMinutes <= 0 {
                    pressure = remainingMinutes > 0 ? 100 : 0
                } else {
                    pressure = min(100, (requiredMinutesWithBuffer * 100) / availableMinutes)
                }
                status = remainingMinutes > 0 ? .impossible : .healthy
            } else {
                // Calculate total capacity until deadline, accounting for stones each day
                let totalCapacityMinutes = daysRemaining * availableMinutes

                if totalCapacityMinutes <= 0 {
                    pressure = 100
                } else {
                    pressure = min(100, (requiredMinutesWithBuffer * 100) / totalCapacityMinutes)
                }

                // Status based on pressure thresholds (from old repo)
                // >90% = Impossible, >75% = At Risk, >50% = Tight, else = Healthy
                switch pressure {
                case 91...: status = .impossible
                case 76...90: status = .atRisk
                case 51...75: status = .tight
                default: status = .healthy
                }
            }

            let projectPressure = ProjectPressure(
                project: project,
                deadline: deadline,
                daysRemaining: daysRemaining,
                remainingMinutes: remainingMinutes,
                requiredMinutesWithBuffer: requiredMinutesWithBuffer,
                totalCapacityMinutes: daysRemaining * dailyCapacityMinutes,
                stoneMinutes: stoneMinutes * daysRemaining,
                availableCapacityMinutes: daysRemaining * availableMinutes,
                pressure: pressure,
                status: status
            )
            projectPressures.append(projectPressure)

            if status.severity > worstStatus.severity {
                worstStatus = status
            }
            if pressure > worstPressure {
                worstPressure = pressure
            }
        }

        return DayPressure(
            date: date,
            dailyCapacityMinutes: dailyCapacityMinutes,
            stoneMinutes: stoneMinutes,
            availableMinutes: availableMinutes,
            projectPressures: projectPressures,
            aggregateStatus: worstStatus,
            worstPressure: worstPressure
        )
    }

    /// Calculate stone (fixed event) minutes for a specific day
    static func calculateStoneMinutes(for date: Date, stones: [StoneEvent]) -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }

        var totalMinutes = 0

        for stone in stones {
            guard stone.occursOn(date: date) else { continue }
            totalMinutes += stone.durationMinutes
        }

        return totalMinutes
    }

    // MARK: - Load-Based Calculation (for CalendarView)

    /// Calculate daily load percentage if user distributes work evenly to meet all deadlines.
    /// Returns a value from 0.0 (empty) to 1.0+ (overloaded).
    static func calculateDayLoad(
        for date: Date,
        projects: [Project],
        dailyCapacityMinutes: Int = UserPreferences.shared.dailyProductiveHours * 60
    ) -> Double {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        // Only calculate for today and future days
        guard dayStart >= today else { return 0 }

        var totalAllocatedMinutes: Double = 0

        for project in projects where project.isActive {
            guard let deadline = project.deadline else { continue }

            let deadlineStart = calendar.startOfDay(for: deadline)

            // Skip if deadline already passed
            guard deadlineStart >= today else { continue }

            // Skip if this day is after the deadline
            guard dayStart <= deadlineStart else { continue }

            // Calculate days from today to deadline (inclusive)
            let totalDays = max(1, (calendar.dateComponents([.day], from: today, to: deadlineStart).day ?? 0) + 1)

            // Remaining work in minutes
            let remainingMinutes = Double(project.remainingHours * 60)

            // Daily allocation = remaining work / days until deadline
            let dailyAllocation = remainingMinutes / Double(totalDays)

            // Add this project's allocation to today's load
            totalAllocatedMinutes += dailyAllocation
        }

        // Return load as percentage of capacity
        guard dailyCapacityMinutes > 0 else { return 0 }
        return totalAllocatedMinutes / Double(dailyCapacityMinutes)
    }

    // MARK: - Simplified Methods (for CalendarView)

    /// Calculate the worst feasibility status for a given day (simplified)
    static func aggregateFeasibility(
        for date: Date,
        projects: [Project],
        stones: [StoneEvent] = [],
        dailyCapacityHours: Int = UserPreferences.shared.dailyProductiveHours
    ) -> FeasibilityStatus {
        let dayPressure = calculateDayPressure(
            for: date,
            projects: projects,
            stones: stones,
            dailyCapacityHours: dailyCapacityHours
        )
        return dayPressure.aggregateStatus
    }

    /// Overload for backward compatibility
    static func aggregateFeasibility(for date: Date, projects: [Project]) -> FeasibilityStatus {
        return aggregateFeasibility(for: date, projects: projects, stones: [], dailyCapacityHours: UserPreferences.shared.dailyProductiveHours)
    }

    /// Check if any project has a deadline on a specific day
    static func hasDeadline(on date: Date, projects: [Project]) -> Bool {
        let calendar = Calendar.current
        return projects.contains { project in
            guard let deadline = project.deadline else { return false }
            return calendar.isDate(deadline, inSameDayAs: date)
        }
    }

    /// Get the projects that have deadlines on a specific day
    static func projectsWithDeadline(on date: Date, projects: [Project]) -> [Project] {
        let calendar = Calendar.current
        return projects.filter { project in
            guard let deadline = project.deadline else { return false }
            return calendar.isDate(deadline, inSameDayAs: date)
        }
    }
}
