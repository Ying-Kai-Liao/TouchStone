import Foundation
import SwiftData
import WidgetKit

// MARK: - Widget Data Sync Service

/// Service to sync app data to widgets via App Groups.
/// Call `sync()` whenever relevant data changes.
class WidgetDataSync {
    static let shared = WidgetDataSync()

    private let suiteName = "group.touchstone.widget"
    private let dataKey = "widgetData"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Sync Methods

    /// Sync widget data from current app state.
    /// Call this after any data changes that should update widgets.
    func sync(
        stones: [StoneEvent],
        projects: [Project],
        rules: [Rule] = []
    ) {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // Get today's stone instances
        let todayStones = stones
            .filter { $0.occursOn(date: today) }
            .map { StoneEventInstance(event: $0, on: today) }
            .sorted { $0.startTime < $1.startTime }

        // Calculate current status
        let currentStatus = calculateCurrentStatus(stones: todayStones, now: now)

        // Find next stone
        let nextStone = todayStones
            .first { $0.startTime > now }
            .map { stoneInfo(from: $0) }

        // Get suggested project (highest priority active project)
        let suggestedProject = calculateSuggestedProject(projects: projects, now: now)

        // Calculate today's stats
        let todayStats = calculateTodayStats(
            projects: projects,
            stones: todayStones,
            now: now
        )

        // Create widget data
        let widgetData = WidgetData(
            date: today,
            currentStatus: currentStatus,
            nextStone: nextStone,
            suggestedProject: suggestedProject,
            todayStats: todayStats,
            updatedAt: now
        )

        // Save to shared defaults
        save(widgetData)

        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Quick sync for touch log updates
    func syncAfterTouch(
        stones: [StoneEvent],
        projects: [Project]
    ) {
        sync(stones: stones, projects: projects)
    }

    // MARK: - Private Helpers

    private func calculateCurrentStatus(stones: [StoneEventInstance], now: Date) -> CurrentStatus {
        // Check if currently in a stone
        if let currentStone = stones.first(where: { $0.startTime <= now && now < $0.endTime }) {
            return .inStone(stoneInfo(from: currentStone))
        }

        // Find next stone to determine "free until"
        if let nextStone = stones.first(where: { $0.startTime > now }) {
            return .free(until: nextStone.startTime)
        }

        return .free(until: nil)
    }

    private func stoneInfo(from instance: StoneEventInstance) -> StoneInfo {
        StoneInfo(
            id: instance.event.id,
            title: instance.event.title,
            startTime: instance.startTime,
            endTime: instance.endTime
        )
    }

    private func calculateSuggestedProject(projects: [Project], now: Date) -> ProjectInfo? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        // Filter to active projects with remaining work or simple projects
        let activeProjects = projects.filter { project in
            guard project.isActive else { return false }
            if project.totalPlannedMinutes > 0 {
                return project.remainingHours > 0
            }
            return true
        }

        guard !activeProjects.isEmpty else { return nil }

        // Score projects for priority
        let scored = activeProjects.map { project -> (Project, Double) in
            var score: Double = 0

            // 1. Deadline urgency (highest priority)
            if let daysUntil = project.daysUntilDeadline {
                if daysUntil < 0 {
                    score += 200 // Overdue
                } else if daysUntil <= 3 {
                    score += 150 - Double(daysUntil) * 15
                } else if daysUntil <= 7 {
                    score += 100 - Double(daysUntil - 3) * 10
                }
            }

            // 2. Staleness (not touched recently)
            if let days = project.daysSinceLastTouch {
                score += min(50, Double(days) * 5)
            } else {
                score += 50 // Never touched = high priority
            }

            // 3. Has remaining work
            if project.remainingHours > 0 {
                score += 25
            }

            return (project, score)
        }

        // Get highest scored project
        let topProject = scored.sorted { $0.1 > $1.1 }.first?.0

        return topProject.map { projectInfo(from: $0) }
    }

    private func projectInfo(from project: Project) -> ProjectInfo {
        ProjectInfo(
            id: project.id,
            title: project.title,
            daysSinceTouch: project.daysSinceLastTouch,
            completedHours: project.completedHours,
            plannedHours: project.totalPlannedHours,
            currentPhase: project.activePhase?.title ?? project.currentPhase,
            hasDeadline: project.deadline != nil,
            daysUntilDeadline: project.daysUntilDeadline
        )
    }

    private func calculateTodayStats(
        projects: [Project],
        stones: [StoneEventInstance],
        now: Date
    ) -> TodayStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let prefs = UserPreferences.shared

        // Calculate touches and minutes today
        var touchCount = 0
        var touchedMinutes = 0

        for project in projects {
            for log in project.touchLogs {
                if calendar.startOfDay(for: log.timestamp) == today {
                    touchCount += 1
                    touchedMinutes += log.durationMinutes
                }
            }
        }

        // Calculate capacity (total productive minutes minus stone time)
        let stoneMinutes = stones.reduce(0) { $0 + $1.event.durationMinutes }
        let capacityMinutes = max(0, prefs.dailyProductiveMinutes - stoneMinutes)

        return TodayStats(
            touchCount: touchCount,
            touchedMinutes: touchedMinutes,
            capacityMinutes: capacityMinutes,
            stonesCount: stones.count
        )
    }

    private func save(_ data: WidgetData) {
        guard let defaults = sharedDefaults else {
            print("[WidgetDataSync] Failed to access shared defaults")
            return
        }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: dataKey)
        }
    }
}

// MARK: - Widget Data Model (Shared with Widget Extension)

/// Lightweight data structure for widget display.
struct WidgetData: Codable {
    let date: Date
    let currentStatus: CurrentStatus
    let nextStone: StoneInfo?
    let suggestedProject: ProjectInfo?
    let todayStats: TodayStats
    let updatedAt: Date

    static let empty = WidgetData(
        date: Date(),
        currentStatus: .free(until: nil),
        nextStone: nil,
        suggestedProject: nil,
        todayStats: TodayStats(touchCount: 0, touchedMinutes: 0, capacityMinutes: 360, stonesCount: 0),
        updatedAt: Date()
    )
}

enum CurrentStatus: Codable {
    case inStone(StoneInfo)
    case free(until: Date?)

    var displayText: String {
        switch self {
        case .inStone(let stone):
            return stone.title
        case .free(until: let date):
            if let date = date {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Free until \(formatter.string(from: date))"
            }
            return "Free"
        }
    }

    var isInStone: Bool {
        if case .inStone = self { return true }
        return false
    }
}

struct StoneInfo: Codable, Identifiable {
    let id: UUID
    let title: String
    let startTime: Date
    let endTime: Date

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }

    var timeUntil: String {
        let now = Date()
        if startTime <= now {
            return "now"
        }
        let interval = startTime.timeIntervalSince(now)
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "in \(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "in \(hours)h"
        }
        return "in \(hours)h \(remainingMinutes)m"
    }

    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
}

struct ProjectInfo: Codable, Identifiable {
    let id: UUID
    let title: String
    let daysSinceTouch: Int?
    let completedHours: Int
    let plannedHours: Int
    let currentPhase: String?
    let hasDeadline: Bool
    let daysUntilDeadline: Int?

    var stalenessText: String? {
        guard let days = daysSinceTouch else { return "Never touched" }
        switch days {
        case 0: return nil
        case 1: return "Yesterday"
        case 2...7: return "\(days) days ago"
        default: return "\(days) days ago"
        }
    }

    var progressText: String {
        if plannedHours > 0 {
            return "\(completedHours)/\(plannedHours)h"
        }
        return "\(completedHours)h"
    }

    var hasProgress: Bool {
        plannedHours > 0
    }

    var progress: Double {
        guard plannedHours > 0 else { return 0 }
        return min(1.0, Double(completedHours) / Double(plannedHours))
    }
}

struct TodayStats: Codable {
    let touchCount: Int
    let touchedMinutes: Int
    let capacityMinutes: Int
    let stonesCount: Int

    var touchedHours: Double {
        Double(touchedMinutes) / 60.0
    }

    var capacityHours: Double {
        Double(capacityMinutes) / 60.0
    }

    var progress: Double {
        guard capacityMinutes > 0 else { return 0 }
        return min(1.0, Double(touchedMinutes) / Double(capacityMinutes))
    }

    var remainingMinutes: Int {
        max(0, capacityMinutes - touchedMinutes)
    }

    var remainingHours: Double {
        Double(remainingMinutes) / 60.0
    }
}
