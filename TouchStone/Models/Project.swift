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
        archetype: Archetype? = nil
    ) {
        self.id = id
        self.title = title
        self.currentPhase = currentPhase
        self.softDeadline = softDeadline
        self.isActive = isActive
        self.createdAt = createdAt
        self.archetypeRaw = archetype?.rawValue
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

    /// Total minutes invested
    var totalMinutesInvested: Int {
        touchLogs.reduce(0) { $0 + $1.durationMinutes }
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

    /// Progress fraction (0.0 to 1.0)
    var progress: Double {
        guard totalSessionCount > 0 else { return 0 }
        return Double(completedSessionCount) / Double(totalSessionCount)
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

    var icon: String {
        switch self {
        case .lab: return "flask"
        case .hunt: return "doc.text.magnifyingglass"
        case .spiral: return "arrow.triangle.2.circlepath"
        case .build: return "hammer"
        }
    }

    /// Default phases for this archetype
    var defaultPhases: [(name: String, type: PhaseType, rule: String)] {
        switch self {
        case .lab:
            return [
                ("Research", .divergent, "Explore widely, no conclusions yet"),
                ("Synthesis", .convergent, "Focus and decide, narrow down"),
                ("Output", .output, "Produce final deliverable")
            ]
        case .hunt:
            return [
                ("Audit", .input, "Assess what needs to be done"),
                ("Gather", .execution, "Collect required materials"),
                ("Execute", .output, "Complete the paperwork")
            ]
        case .spiral:
            return [
                ("Input", .input, "Absorb new information"),
                ("Practice", .output, "Apply what you learned"),
                ("Reflection", .reflection, "Review and consolidate")
            ]
        case .build:
            return [
                ("Spec", .convergent, "Define requirements clearly"),
                ("Dependencies", .execution, "Gather tools and resources"),
                ("Assembly", .output, "Build the thing"),
                ("Testing", .reflection, "Verify it works")
            ]
        }
    }
}
