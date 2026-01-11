import Foundation
import SwiftData

// MARK: - Phase Type

enum PhaseType: String, Codable {
    case divergent   // Explore, brainstorm, gather
    case convergent  // Focus, synthesize, decide
    case execution   // Do the work
    case input       // Learn, absorb
    case output      // Produce, create
    case reflection  // Review, iterate

    var displayName: String {
        switch self {
        case .divergent: return "Divergent"
        case .convergent: return "Convergent"
        case .execution: return "Execution"
        case .input: return "Input"
        case .output: return "Output"
        case .reflection: return "Reflection"
        }
    }

    var icon: String {
        switch self {
        case .divergent: return "arrow.up.left.and.arrow.down.right"
        case .convergent: return "arrow.down.right.and.arrow.up.left"
        case .execution: return "hammer"
        case .input: return "arrow.down.doc"
        case .output: return "arrow.up.doc"
        case .reflection: return "arrow.2.circlepath"
        }
    }
}

// MARK: - Project Phase Model

/// A ProjectPhase represents a distinct stage in a project's workflow.
/// Each phase has a mental rule (cognitive constraint) and contains sessions.
@Model
final class ProjectPhase {
    var id: UUID
    var title: String                    // "Research", "Draft", "Polish"
    var phaseTypeRaw: String             // PhaseType raw value
    var mentalRule: String?              // "No editing, just generate"
    var sequenceOrder: Int               // Order in project (0, 1, 2...)
    var createdAt: Date

    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \PlannedSession.phase)
    var sessions: [PlannedSession] = []

    init(
        id: UUID = UUID(),
        title: String,
        phaseType: PhaseType = .execution,
        mentalRule: String? = nil,
        sequenceOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.phaseTypeRaw = phaseType.rawValue
        self.mentalRule = mentalRule
        self.sequenceOrder = sequenceOrder
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    var phaseType: PhaseType {
        get { PhaseType(rawValue: phaseTypeRaw) ?? .execution }
        set { phaseTypeRaw = newValue.rawValue }
    }

    var sortedSessions: [PlannedSession] {
        sessions.sorted { $0.sequenceOrder < $1.sequenceOrder }
    }

    var completedSessionCount: Int {
        sessions.filter { $0.status == .completed }.count
    }

    var totalSessionCount: Int {
        sessions.count
    }

    var isComplete: Bool {
        !sessions.isEmpty && sessions.allSatisfy { $0.status != .planned }
    }

    var nextPlannedSession: PlannedSession? {
        sortedSessions.first { $0.status == .planned }
    }

    var totalEstimatedMinutes: Int {
        sessions.reduce(0) { $0 + $1.estimatedMinutes }
    }

    var progressString: String {
        "\(completedSessionCount)/\(totalSessionCount)"
    }
}
