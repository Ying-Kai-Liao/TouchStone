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
/// Each phase has a mental rule (cognitive constraint) and a time budget.
/// No longer contains individual sessions - just tracks time invested per phase.
@Model
final class ProjectPhase {
    var id: UUID
    var title: String                    // "Research", "Draft", "Polish"
    var phaseTypeRaw: String             // PhaseType raw value
    var mentalRule: String?              // "No editing, just generate"
    var sequenceOrder: Int               // Order in project (0, 1, 2...)
    var estimatedMinutes: Int            // Time budget for this phase
    var createdAt: Date

    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \TouchLog.phase)
    var touchLogs: [TouchLog] = []       // Work logged specifically to this phase

    init(
        id: UUID = UUID(),
        title: String,
        phaseType: PhaseType = .execution,
        mentalRule: String? = nil,
        sequenceOrder: Int = 0,
        estimatedMinutes: Int = 120,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.phaseTypeRaw = phaseType.rawValue
        self.mentalRule = mentalRule
        self.sequenceOrder = sequenceOrder
        self.estimatedMinutes = estimatedMinutes
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    var phaseType: PhaseType {
        get { PhaseType(rawValue: phaseTypeRaw) ?? .execution }
        set { phaseTypeRaw = newValue.rawValue }
    }

    /// Total minutes invested in this phase
    var minutesInvested: Int {
        touchLogs.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Remaining minutes in time budget
    var remainingMinutes: Int {
        max(0, estimatedMinutes - minutesInvested)
    }

    /// Progress fraction (0.0 to 1.0)
    var progress: Double {
        guard estimatedMinutes > 0 else { return 0 }
        return min(1.0, Double(minutesInvested) / Double(estimatedMinutes))
    }

    /// Whether this phase is complete (time budget exhausted or exceeded)
    var isComplete: Bool {
        minutesInvested >= estimatedMinutes
    }

    /// Formatted estimated time (e.g., "2h", "1.5h")
    var formattedEstimate: String {
        if estimatedMinutes < 60 {
            return "\(estimatedMinutes)m"
        } else if estimatedMinutes % 60 == 0 {
            return "\(estimatedMinutes / 60)h"
        } else {
            let hours = estimatedMinutes / 60
            let mins = estimatedMinutes % 60
            return "\(hours)h \(mins)m"
        }
    }

    /// Progress string like "1.5/2h"
    var progressString: String {
        let investedHours = Double(minutesInvested) / 60.0
        let estimatedHours = Double(estimatedMinutes) / 60.0
        if investedHours == investedHours.rounded() && estimatedHours == estimatedHours.rounded() {
            return "\(Int(investedHours))/\(Int(estimatedHours))h"
        }
        return String(format: "%.1f/%.1fh", investedHours, estimatedHours)
    }
}
