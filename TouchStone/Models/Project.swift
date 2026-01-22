import Foundation
import SwiftData
import SwiftUI

// MARK: - Project Mode

/// Project mode determines how work is tracked
enum ProjectMode: String, Codable, CaseIterable {
    case phase      // Time-based cognitive phases (for creative/research work)
    case milestone  // Checkable deliverables (for task-oriented work)

    var displayName: String {
        switch self {
        case .phase: return "Phase Mode"
        case .milestone: return "Milestone Mode"
        }
    }

    var description: String {
        switch self {
        case .phase: return "Time-based cognitive phases for creative/research work"
        case .milestone: return "Checkable deliverables for task-oriented work"
        }
    }

    var icon: String {
        switch self {
        case .phase: return "clock.arrow.circlepath"
        case .milestone: return "checklist"
        }
    }
}

// MARK: - Project Model

/// A Project represents ongoing work that you want to "touch" regularly.
/// Projects are like water - they flow around the stones (fixed events).
/// There's no scheduling, just gentle reminders to make progress.
@Model
final class Project {
    var id: UUID
    var title: String
    var modeRaw: String = "phase"    // ProjectMode raw value (phase or milestone)
    var currentPhase: String?        // e.g., "Discovery", "Building", "Refinement" (for simple projects)
    var deadline: Date?              // Optional deadline set during strategic plan creation
    var isActive: Bool
    var createdAt: Date
    var archetypeRaw: String?        // Archetype for phase-mode projects
    var totalPlannedMinutes: Int = 0 // Total time budget set during planning (in minutes)
    var planningContext: String?     // Original goal/description used for planning
    var planningNotes: String?       // Additional context notes for AI refinement
    var lastPlanModifiedAt: Date?    // Track when plan was last edited

    @Relationship(deleteRule: .cascade, inverse: \TouchLog.project)
    var touchLogs: [TouchLog] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectPhase.project)
    var phases: [ProjectPhase] = []

    @Relationship(deleteRule: .cascade, inverse: \Milestone.project)
    var milestones: [Milestone] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectDocument.project)
    var documents: [ProjectDocument] = []

    init(
        id: UUID = UUID(),
        title: String,
        mode: ProjectMode = .phase,
        currentPhase: String? = nil,
        deadline: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        archetype: Archetype? = nil,
        totalPlannedMinutes: Int = 0
    ) {
        self.id = id
        self.title = title
        self.modeRaw = mode.rawValue
        self.currentPhase = currentPhase
        self.deadline = deadline
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

    /// Hours touched within a date range (inclusive of start, exclusive of end)
    /// Uses defensive access pattern to avoid SwiftData faulting issues
    func hoursInRange(from startDate: Date, to endDate: Date) -> Double {
        // Copy to local array and safely access properties
        var totalMinutes = 0
        for log in touchLogs {
            // Access timestamp - if this fails on faulted object, skip it
            let ts = log.timestamp
            if ts >= startDate && ts < endDate {
                totalMinutes += log.durationMinutes
            }
        }
        return Double(totalMinutes) / 60.0
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

    // MARK: - Pressure Calculation

    /// Days remaining until deadline (nil if no deadline)
    var daysUntilDeadline: Int? {
        guard let dl = deadline else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: Date(), to: dl).day
    }

    /// Required daily hours to meet deadline
    /// Formula: remainingHours / daysUntilDeadline
    var requiredDailyHours: Double? {
        guard let days = daysUntilDeadline, days > 0 else { return nil }
        return Double(remainingHours) / Double(days)
    }

    /// Pressure ratio: required pace / available capacity
    var pressureRatio: Double {
        guard let required = requiredDailyHours else { return 0 }
        let dailyCapacity = Double(UserPreferences.shared.dailyProductiveHours)
        return required / dailyCapacity
    }

    /// Feasibility status based on pressure ratio
    var feasibilityStatus: FeasibilityStatus {
        guard deadline != nil else { return .noDeadline }

        if let days = daysUntilDeadline, days < 0 {
            return .overdue
        }

        switch pressureRatio {
        case ...0.5: return .healthy      // GREEN - comfortable pace
        case 0.5...0.8: return .tight     // YELLOW - manageable but busy
        case 0.8...1.0: return .atRisk    // ORANGE - pushing limits
        default: return .impossible       // RED - can't make it
        }
    }

    // MARK: - Mode Properties

    /// The project's mode (phase or milestone)
    var mode: ProjectMode {
        get { ProjectMode(rawValue: modeRaw) ?? .phase }
        set { modeRaw = newValue.rawValue }
    }

    /// Whether this is a phase-mode project
    var isPhaseMode: Bool {
        mode == .phase
    }

    /// Whether this is a milestone-mode project
    var isMilestoneMode: Bool {
        mode == .milestone
    }

    // MARK: - Strategic Planning Properties

    /// Whether this project has a strategic plan (phases for phase-mode, milestones for milestone-mode)
    var hasStrategicPlan: Bool {
        switch mode {
        case .phase: return !phases.isEmpty
        case .milestone: return !milestones.isEmpty
        }
    }

    /// The project's archetype (for phase-mode projects only)
    var archetype: Archetype? {
        get { archetypeRaw.flatMap { Archetype(rawValue: $0) } }
        set { archetypeRaw = newValue?.rawValue }
    }

    /// Sorted phases by sequence order
    var sortedPhases: [ProjectPhase] {
        phases.sorted { $0.sequenceOrder < $1.sequenceOrder }
    }

    /// Sorted milestones by sequence order
    var sortedMilestones: [Milestone] {
        milestones.sorted { $0.sequenceOrder < $1.sequenceOrder }
    }

    /// The current active phase (first phase that is not complete)
    var activePhase: ProjectPhase? {
        sortedPhases.first { !$0.isComplete }
    }

    /// The next incomplete milestone
    var nextMilestone: Milestone? {
        sortedMilestones.first { !$0.isCompleted }
    }

    /// Number of completed milestones
    var completedMilestoneCount: Int {
        milestones.filter { $0.isCompleted }.count
    }

    /// Total number of milestones
    var totalMilestoneCount: Int {
        milestones.count
    }

    /// Progress fraction (0.0 to 1.0)
    /// - Phase mode: based on time invested vs planned
    /// - Milestone mode: based on milestones completed
    var progress: Double {
        switch mode {
        case .phase:
            guard totalPlannedMinutes > 0 else { return 0 }
            return min(1.0, Double(totalMinutesInvested) / Double(totalPlannedMinutes))
        case .milestone:
            guard totalMilestoneCount > 0 else { return 0 }
            return Double(completedMilestoneCount) / Double(totalMilestoneCount)
        }
    }

    /// Total estimated minutes from all phases
    var totalEstimatedMinutes: Int {
        phases.reduce(0) { $0 + $1.estimatedMinutes }
    }

    /// Remaining estimated minutes (for phases with remaining time budget)
    var remainingEstimatedMinutes: Int {
        let invested = totalMinutesInvested
        return max(0, totalPlannedMinutes - invested)
    }

    /// Progress string based on mode
    var progressString: String {
        switch mode {
        case .phase:
            if totalPlannedMinutes > 0 {
                let invested = totalMinutesInvested / 60
                let planned = totalPlannedMinutes / 60
                return "\(invested)/\(planned) hrs"
            } else {
                return "\(totalMinutesInvested / 60) hrs"
            }
        case .milestone:
            return "\(completedMilestoneCount)/\(totalMilestoneCount) done"
        }
    }

    /// Summary of current progress for AI context
    var progressSummary: String {
        switch mode {
        case .phase:
            let invested = totalMinutesInvested / 60
            let planned = totalPlannedMinutes / 60
            let phaseName = activePhase?.title ?? "None"
            return "Progress: \(invested)/\(planned) hours invested. Current phase: \(phaseName)."
        case .milestone:
            let completed = completedMilestoneCount
            let total = totalMilestoneCount
            let nextName = nextMilestone?.title ?? "None"
            return "Progress: \(completed)/\(total) milestones completed. Next: \(nextName)."
        }
    }

    /// Combined document context for AI refinement
    var documentContext: String {
        documents
            .compactMap { $0.extractedText }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n---\n\n")
    }

    /// Current intention text (for focus mode)
    /// - Phase mode: active phase's mental rule
    /// - Milestone mode: next milestone title
    var currentIntention: String? {
        switch mode {
        case .phase:
            return activePhase?.mentalRule
        case .milestone:
            return nextMilestone?.title
        }
    }
}

// MARK: - Feasibility Status

/// Pressure-based feasibility status for deadline tracking
enum FeasibilityStatus: String, Codable {
    case noDeadline     // No deadline set
    case healthy        // Pressure ≤ 0.5 (GREEN)
    case tight          // Pressure 0.5-0.8 (YELLOW)
    case atRisk         // Pressure 0.8-1.0 (ORANGE)
    case impossible     // Pressure > 1.0 (RED)
    case overdue        // Past deadline (DARK RED)

    var color: Color {
        switch self {
        case .noDeadline: return .clear
        case .healthy: return .green
        case .tight: return .yellow
        case .atRisk: return .orange
        case .impossible: return .red
        case .overdue: return Color(red: 0.6, green: 0, blue: 0)
        }
    }

    var severity: Int {
        switch self {
        case .noDeadline: return 0
        case .healthy: return 1
        case .tight: return 2
        case .atRisk: return 3
        case .impossible: return 4
        case .overdue: return 5
        }
    }

    var displayName: String {
        switch self {
        case .noDeadline: return "No Deadline"
        case .healthy: return "Healthy"
        case .tight: return "Tight"
        case .atRisk: return "At Risk"
        case .impossible: return "Impossible"
        case .overdue: return "Overdue"
        }
    }
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

// MARK: - Deadline-Aware Scheduling Extensions

extension Project {

    /// Check if project is due within this week (7 days from date)
    func isDueThisWeek(from date: Date = Date()) -> Bool {
        guard let deadline = deadline else { return false }
        let calendar = Calendar.current
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: date)) ?? date
        return deadline >= date && deadline < endOfWeek
    }

    /// Check if project is in "crunch mode" - within threshold days of deadline with remaining work
    func isInCrunchMode(from date: Date = Date(), threshold: Int = 2) -> Bool {
        guard let daysUntil = daysUntilDeadline,
              daysUntil >= 0,           // Not yet overdue (overdue is handled separately)
              daysUntil <= threshold,   // Within crunch threshold
              remainingHours > 0        // Has work remaining
        else { return false }
        return true
    }

    /// Days until end of current week from a given date
    func daysUntilEndOfWeek(from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // Days until Sunday (end of week)
        let daysToSunday = (8 - weekday) % 7
        return daysToSunday == 0 ? 7 : daysToSunday
    }

    /// Whether the project is overdue (past deadline with remaining work)
    var isOverdue: Bool {
        guard let daysUntil = daysUntilDeadline else { return false }
        return daysUntil < 0 && remainingHours > 0
    }

    /// Calculate urgency score (0-200) based on deadline proximity
    func urgencyScore(from date: Date = Date()) -> Double {
        guard let daysUntil = daysUntilDeadline else { return 0 }

        // Overdue: maximum urgency
        if daysUntil < 0 {
            return 200
        }

        // Due in 1-3 days: 150-195 points (linear interpolation)
        if daysUntil <= 3 {
            // daysUntil 0 -> 195, daysUntil 3 -> 150
            return 195 - (Double(daysUntil) * 15)
        }

        // Due in 4-7 days: 100-150 points
        if daysUntil <= 7 {
            // daysUntil 4 -> ~146, daysUntil 7 -> 100
            return 150 - (Double(daysUntil - 3) * 12.5)
        }

        // Due in 8+ days: decays from 100
        // Using exponential decay: 100 * 0.9^(days-7)
        let daysOver7 = daysUntil - 7
        return 100 * pow(0.9, Double(daysOver7))
    }
}
