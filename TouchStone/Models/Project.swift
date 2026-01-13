import Foundation
import SwiftData

// MARK: - Project Model

/// A Project represents ongoing work that you want to "touch" regularly.
/// Projects are like water - they flow around the stones (fixed events).
/// There's no scheduling, just gentle reminders to make progress.
@Model
final class Project {
    var id: UUID
    var title: String
    var currentPhase: String?       // e.g., "Discovery", "Building", "Refinement" (for simple projects)
    var softDeadline: Date?         // Optional gentle reminder, not pressure
    var isActive: Bool
    var createdAt: Date
    var archetypeRaw: String?       // Archetype for strategic projects
    var totalPlannedMinutes: Int = 0  // Total time budget set during planning (in minutes)

    @Relationship(deleteRule: .cascade, inverse: \TouchLog.project)
    var touchLogs: [TouchLog] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectPhase.project)
    var phases: [ProjectPhase] = []

    init(
        id: UUID = UUID(),
        title: String,
        currentPhase: String? = nil,
        softDeadline: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        archetype: Archetype? = nil,
        totalPlannedMinutes: Int = 0
    ) {
        self.id = id
        self.title = title
        self.currentPhase = currentPhase
        self.softDeadline = softDeadline
        self.isActive = isActive
        self.createdAt = createdAt
        self.archetypeRaw = archetype?.rawValue
        self.totalPlannedMinutes = totalPlannedMinutes
    }

    // MARK: - Computed Properties

    /// Number of times touched today
    var touchCountToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return touchLogs.filter { calendar.startOfDay(for: $0.timestamp) == today }.count
    }

    /// Total touch count all time
    var totalTouchCount: Int {
        touchLogs.count
    }

    /// Total minutes invested (from touch logs)
    var totalMinutesInvested: Int {
        touchLogs.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Total planned hours for this project
    var totalPlannedHours: Int {
        totalPlannedMinutes / 60
    }

    /// Completed hours (each touch = 1 hour)
    var completedHours: Int {
        totalMinutesInvested / 60
    }

    /// Remaining hours
    var remainingHours: Int {
        max(0, totalPlannedHours - completedHours)
    }

    /// Hours string like "12/30 hrs" or "12 hrs" for simple projects
    var hoursString: String {
        if totalPlannedMinutes > 0 {
            return "\(completedHours)/\(totalPlannedHours) hrs"
        } else {
            return "\(completedHours) hrs"
        }
    }

    /// Hours touched today
    var hoursTouchedToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayMinutes = touchLogs
            .filter { calendar.startOfDay(for: $0.timestamp) == today }
            .reduce(0) { $0 + $1.durationMinutes }
        return todayMinutes / 60
    }

    /// Last touched date
    var lastTouchedAt: Date? {
        touchLogs.max(by: { $0.timestamp < $1.timestamp })?.timestamp
    }

    /// Days since last touch (nil if never touched)
    var daysSinceLastTouch: Int? {
        guard let lastTouch = lastTouchedAt else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: lastTouch, to: Date()).day
    }

    /// Human-readable last touch description
    var lastTouchDescription: String {
        guard let days = daysSinceLastTouch else {
            return "Never touched"
        }
        switch days {
        case 0: return "Touched today"
        case 1: return "Touched yesterday"
        default: return "Touched \(days) days ago"
        }
    }

    /// Check if project is "stale" (not touched in a while)
    var isStale: Bool {
        guard let days = daysSinceLastTouch else { return true }
        return days > 7
    }

    /// Soft deadline status
    var deadlineStatus: DeadlineStatus {
        guard let deadline = softDeadline else { return .none }
        let calendar = Calendar.current
        let daysUntil = calendar.dateComponents([.day], from: Date(), to: deadline).day ?? 0

        if daysUntil < 0 {
            return .passed
        } else if daysUntil <= 7 {
            return .approaching
        } else {
            return .comfortable
        }
    }

    // MARK: - Strategic Planning Properties

    /// Whether this project has a strategic plan with phases
    var hasStrategicPlan: Bool {
        !phases.isEmpty
    }

    /// The project's archetype (for strategic projects)
    var archetype: Archetype? {
        get { archetypeRaw.flatMap { Archetype(rawValue: $0) } }
        set { archetypeRaw = newValue?.rawValue }
    }

    /// Sorted phases by sequence order
    var sortedPhases: [ProjectPhase] {
        phases.sorted { $0.sequenceOrder < $1.sequenceOrder }
    }

    /// The current active phase (first phase with incomplete sessions)
    var activePhase: ProjectPhase? {
        sortedPhases.first { !$0.isComplete }
    }

    /// Next planned session across all phases
    var nextPlannedSession: PlannedSession? {
        for phase in sortedPhases {
            if let session = phase.nextPlannedSession {
                return session
            }
        }
        return nil
    }

    /// Number of completed sessions across all phases
    var completedSessionCount: Int {
        phases.flatMap { $0.sessions }.filter { $0.status == .completed }.count
    }

    /// Total number of sessions across all phases
    var totalSessionCount: Int {
        phases.flatMap { $0.sessions }.count
    }

    /// Progress fraction (0.0 to 1.0) based on hours
    var progress: Double {
        guard totalPlannedMinutes > 0 else { return 0 }
        return min(1.0, Double(totalMinutesInvested) / Double(totalPlannedMinutes))
    }

    /// Total estimated minutes for all sessions
    var totalEstimatedMinutes: Int {
        phases.flatMap { $0.sessions }.reduce(0) { $0 + $1.estimatedMinutes }
    }

    /// Remaining estimated minutes
    var remainingEstimatedMinutes: Int {
        phases.flatMap { $0.sessions }
            .filter { $0.status == .planned }
            .reduce(0) { $0 + $1.estimatedMinutes }
    }

    /// Progress string like "2/6 sessions"
    var progressString: String {
        "\(completedSessionCount)/\(totalSessionCount) sessions"
    }
}

// MARK: - Deadline Status

enum DeadlineStatus {
    case none
    case comfortable   // > 7 days away
    case approaching   // <= 7 days away
    case passed        // Past deadline
}

// MARK: - Phase Template

/// Template for a phase within an archetype, including default time allocation
struct PhaseTemplate {
    let name: String
    let type: PhaseType
    let rule: String
    let defaultPercent: Int  // Default % of total time
}

// MARK: - Archetype

enum Archetype: String, Codable, CaseIterable {
    case lab      // Creative/Research/Writing
    case hunt     // Bureaucratic/Admin
    case spiral   // Skill Acquisition/Learning
    case build    // Engineering/Construction

    var displayName: String {
        switch self {
        case .lab: return "LAB"
        case .hunt: return "HUNT"
        case .spiral: return "SPIRAL"
        case .build: return "BUILD"
        }
    }

    var description: String {
        switch self {
        case .lab: return "Creative, research, writing"
        case .hunt: return "Administrative, bureaucratic"
        case .spiral: return "Learning, skill acquisition"
        case .build: return "Engineering, construction"
        }
    }

    /// Detailed description with failure mode
    var detailedDescription: String {
        switch self {
        case .lab:
            return "Creative work requiring exploration then synthesis. Failure mode: Getting stuck in research forever."
        case .hunt:
            return "Bureaucratic tasks with gatekeepers. Failure mode: Missing one document and getting blocked."
        case .spiral:
            return "Skill acquisition requiring practice loops. Failure mode: Passive consumption without doing."
        case .build:
            return "Construction with dependencies. Failure mode: Starting before materials ready."
        }
    }

    var icon: String {
        switch self {
        case .lab: return "flask"
        case .hunt: return "doc.text.magnifyingglass"
        case .spiral: return "arrow.triangle.2.circlepath"
        case .build: return "hammer"
        }
    }

    /// Phase structure for this archetype with default time allocations
    var phaseStructure: [PhaseTemplate] {
        switch self {
        case .lab:
            return [
                PhaseTemplate(name: "Exploration", type: .divergent,
                    rule: "Explore widely, no conclusions yet",
                    defaultPercent: 25),
                PhaseTemplate(name: "Bricklaying", type: .execution,
                    rule: "Hermit mode: no new inputs, no editing worry, just produce",
                    defaultPercent: 50),
                PhaseTemplate(name: "Refining", type: .convergent,
                    rule: "No new research, only polish and perfect",
                    defaultPercent: 25)
            ]
        case .hunt:
            return [
                PhaseTemplate(name: "Audit", type: .input,
                    rule: "List everything needed, don't start gathering yet",
                    defaultPercent: 20),
                PhaseTemplate(name: "Gathering", type: .execution,
                    rule: "Scavenge all assets, do NOT start execution until complete",
                    defaultPercent: 40),
                PhaseTemplate(name: "Execution", type: .output,
                    rule: "Batch similar tasks, no new gathering",
                    defaultPercent: 40)
            ]
        case .spiral:
            return [
                PhaseTemplate(name: "Input", type: .input,
                    rule: "Absorb theory and examples",
                    defaultPercent: 30),
                PhaseTemplate(name: "Output", type: .output,
                    rule: "Struggle and practice WITHOUT help",
                    defaultPercent: 50),
                PhaseTemplate(name: "Reflection", type: .reflection,
                    rule: "Review what worked and what didn't",
                    defaultPercent: 20)
            ]
        case .build:
            return [
                PhaseTemplate(name: "Spec", type: .convergent,
                    rule: "Define requirements clearly, no building yet",
                    defaultPercent: 15),
                PhaseTemplate(name: "Dependencies", type: .execution,
                    rule: "Gather tools and resources, verify availability",
                    defaultPercent: 20),
                PhaseTemplate(name: "Assembly", type: .output,
                    rule: "Build following spec, no scope creep",
                    defaultPercent: 50),
                PhaseTemplate(name: "Testing", type: .reflection,
                    rule: "Verify it works, document issues",
                    defaultPercent: 15)
            ]
        }
    }

    /// Default phases for this archetype (legacy compatibility)
    var defaultPhases: [(name: String, type: PhaseType, rule: String)] {
        phaseStructure.map { ($0.name, $0.type, $0.rule) }
    }
}
