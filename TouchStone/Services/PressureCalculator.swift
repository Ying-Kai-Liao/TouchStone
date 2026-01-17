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

    /// Result for day load calculation containing allocation details
    struct DayLoadResult {
        let load: Double                    // 0.0 = empty, 1.0 = full, >1.0 = overloaded
        let isBufferDay: Bool               // True if this day is in the buffer period for any project
        let allocatedMinutes: Double        // Total work allocated to this day
        let availableMinutes: Int           // Capacity minus stones
        let projectAllocations: [ProjectAllocation]
        let usedBufferDays: Bool            // True if buffer days were consumed due to overload

        struct ProjectAllocation {
            let project: Project
            let allocatedMinutes: Double
            let isBufferDay: Bool
            let workDayIndex: Int?          // nil if buffer day
            let totalWorkDays: Int
            let bufferDays: Int
            let effectiveBufferDays: Int    // Actual buffer after auto-reduction
            let isOverloaded: Bool          // True if this project can't fit
        }
    }

    /// Calculate daily load percentage for a specific day using smart scheduling.
    /// Algorithm:
    /// 1. Reserve buffer days (% of total) before each deadline
    /// 2. Account for stones reducing daily capacity
    /// 3. Distribute work proportionally to available capacity across work days
    /// 4. Auto-use buffer days when work exceeds 100% capacity
    /// 5. Prioritize projects by deadline (earlier deadlines first)
    /// Returns a value from 0.0 (empty) to 1.0+ (overloaded).
    static func calculateDayLoad(
        for date: Date,
        projects: [Project],
        stones: [StoneEvent] = [],
        dailyCapacityMinutes: Int = UserPreferences.shared.dailyProductiveHours * 60,
        bufferPercent: Int = UserPreferences.shared.deadlineBufferPercent
    ) -> Double {
        return calculateDayLoadDetailed(
            for: date,
            projects: projects,
            stones: stones,
            dailyCapacityMinutes: dailyCapacityMinutes,
            bufferPercent: bufferPercent
        ).load
    }

    /// Calculate detailed daily load with breakdown by project
    /// Uses smart scheduling with auto-buffer consumption and deadline prioritization
    static func calculateDayLoadDetailed(
        for date: Date,
        projects: [Project],
        stones: [StoneEvent] = [],
        dailyCapacityMinutes: Int = UserPreferences.shared.dailyProductiveHours * 60,
        bufferPercent: Int = UserPreferences.shared.deadlineBufferPercent
    ) -> DayLoadResult {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        // Only calculate for today and future days
        guard dayStart >= today else {
            return DayLoadResult(
                load: 0,
                isBufferDay: false,
                allocatedMinutes: 0,
                availableMinutes: dailyCapacityMinutes,
                projectAllocations: [],
                usedBufferDays: false
            )
        }

        // Calculate stone minutes for THIS day
        let stoneMinutes = calculateStoneMinutes(for: date, stones: stones)
        let availableMinutes = max(0, dailyCapacityMinutes - stoneMinutes)
        let dayIndex = calendar.dateComponents([.day], from: today, to: dayStart).day ?? 0

        // Filter and sort projects by deadline (earlier first for priority)
        let relevantProjects = projects
            .filter { $0.isActive && $0.deadline != nil }
            .filter { project in
                let deadlineStart = calendar.startOfDay(for: project.deadline!)
                return deadlineStart >= dayStart
            }
            .sorted { p1, p2 in
                p1.deadline! < p2.deadline!
            }

        // Build project info with optimal buffers
        struct ProjectInfo {
            let project: Project
            let totalDays: Int
            let optimalBufferDays: Int
            var effectiveBufferDays: Int
            let remainingMinutes: Double
        }

        var projectInfos: [ProjectInfo] = relevantProjects.map { project in
            let deadline = project.deadline!
            let deadlineStart = calendar.startOfDay(for: deadline)
            let totalDays = max(1, (calendar.dateComponents([.day], from: today, to: deadlineStart).day ?? 0) + 1)
            let optimalBufferDays = Int(ceil(Double(totalDays) * Double(bufferPercent) / 100.0))
            let remainingMinutes = Double(project.remainingHours * 60)
            return ProjectInfo(
                project: project,
                totalDays: totalDays,
                optimalBufferDays: optimalBufferDays,
                effectiveBufferDays: optimalBufferDays,
                remainingMinutes: remainingMinutes
            )
        }

        // Helper to calculate allocation for a day given current buffer settings
        func calculateDayAllocation(for info: ProjectInfo) -> Double {
            let workDays = max(1, info.totalDays - info.effectiveBufferDays)

            // If this day is in buffer period, no allocation
            if dayIndex >= workDays {
                return 0
            }

            // Calculate total available across all work days
            var totalAvailable: Double = 0
            for offset in 0..<workDays {
                guard let workDate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                let dayStones = calculateStoneMinutes(for: workDate, stones: stones)
                totalAvailable += Double(max(0, dailyCapacityMinutes - dayStones))
            }

            if totalAvailable > 0 {
                return info.remainingMinutes * (Double(availableMinutes) / totalAvailable)
            } else {
                return info.remainingMinutes / Double(workDays)
            }
        }

        // Calculate total load with current buffer settings
        func calculateTotalLoad() -> Double {
            let total = projectInfos.reduce(0.0) { $0 + calculateDayAllocation(for: $1) }
            return availableMinutes > 0 ? total / Double(availableMinutes) : (total > 0 ? 2.0 : 0)
        }

        // Iteratively reduce buffers while load > 100% and buffers remain
        var iterations = 0
        let maxIterations = 100 // Safety limit

        while calculateTotalLoad() > 1.0 && iterations < maxIterations {
            iterations += 1

            // Find projects that still have buffer days to reduce
            // Prioritize reducing buffer from projects with later deadlines (preserve earlier deadline buffers)
            var reducedAny = false

            // Sort by deadline descending (later deadlines first) for buffer reduction
            let sortedIndices = projectInfos.indices.sorted { i1, i2 in
                projectInfos[i1].project.deadline! > projectInfos[i2].project.deadline!
            }

            for idx in sortedIndices {
                if projectInfos[idx].effectiveBufferDays > 0 {
                    projectInfos[idx].effectiveBufferDays -= 1
                    reducedAny = true
                    break // Reduce one buffer day at a time, then recalculate
                }
            }

            if !reducedAny {
                break // No more buffers to reduce
            }
        }

        // Build final allocations
        var totalAllocatedMinutes: Double = 0
        var isAnyBufferDay = false
        var usedBufferDays = false
        var projectAllocations: [DayLoadResult.ProjectAllocation] = []

        for info in projectInfos {
            if info.effectiveBufferDays < info.optimalBufferDays {
                usedBufferDays = true
            }

            let workDays = max(1, info.totalDays - info.effectiveBufferDays)
            let isBufferDay = dayIndex >= workDays

            if isBufferDay {
                isAnyBufferDay = true
                projectAllocations.append(DayLoadResult.ProjectAllocation(
                    project: info.project,
                    allocatedMinutes: 0,
                    isBufferDay: true,
                    workDayIndex: nil,
                    totalWorkDays: workDays,
                    bufferDays: info.optimalBufferDays,
                    effectiveBufferDays: info.effectiveBufferDays,
                    isOverloaded: false
                ))
                continue
            }

            // Calculate allocation
            var totalAvailable: Double = 0
            for offset in 0..<workDays {
                guard let workDate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                let dayStones = calculateStoneMinutes(for: workDate, stones: stones)
                totalAvailable += Double(max(0, dailyCapacityMinutes - dayStones))
            }

            let allocation: Double
            if totalAvailable > 0 {
                allocation = info.remainingMinutes * (Double(availableMinutes) / totalAvailable)
            } else {
                allocation = info.remainingMinutes / Double(workDays)
            }

            // Check if project is truly overloaded (can't fit even with 0 buffer)
            let maxCapacity: Double = {
                var total: Double = 0
                for offset in 0..<info.totalDays {
                    guard let workDate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                    let dayStones = calculateStoneMinutes(for: workDate, stones: stones)
                    total += Double(max(0, dailyCapacityMinutes - dayStones))
                }
                return total
            }()
            let isOverloaded = info.remainingMinutes > maxCapacity

            totalAllocatedMinutes += allocation
            projectAllocations.append(DayLoadResult.ProjectAllocation(
                project: info.project,
                allocatedMinutes: allocation,
                isBufferDay: false,
                workDayIndex: dayIndex,
                totalWorkDays: workDays,
                bufferDays: info.optimalBufferDays,
                effectiveBufferDays: info.effectiveBufferDays,
                isOverloaded: isOverloaded
            ))
        }

        // Return load as percentage of available capacity
        let load: Double
        if availableMinutes > 0 {
            load = totalAllocatedMinutes / Double(availableMinutes)
        } else {
            load = totalAllocatedMinutes > 0 ? 2.0 : 0
        }

        return DayLoadResult(
            load: load,
            isBufferDay: isAnyBufferDay && totalAllocatedMinutes == 0,
            allocatedMinutes: totalAllocatedMinutes,
            availableMinutes: availableMinutes,
            projectAllocations: projectAllocations,
            usedBufferDays: usedBufferDays
        )
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
