import Foundation
import SwiftData

// MARK: - Session Status

enum SessionStatus: String, Codable {
    case planned
    case completed
    case skipped

    var displayName: String {
        switch self {
        case .planned: return "Planned"
        case .completed: return "Completed"
        case .skipped: return "Skipped"
        }
    }

    var icon: String {
        switch self {
        case .planned: return "circle"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "arrow.right.circle"
        }
    }
}

// MARK: - Planned Session Model

/// A PlannedSession represents a specific work block within a phase.
/// Sessions are 60-90 minute focused work periods with clear goals.
@Model
final class PlannedSession {
    var id: UUID
    var title: String                    // "Literature review"
    var goal: String?                    // "Read 5 papers, take notes"
    var estimatedMinutes: Int            // 60-90 min default
    var sequenceOrder: Int               // Order in phase
    var statusRaw: String                // SessionStatus raw value
    var completedAt: Date?
    var createdAt: Date
    var isManuallyEdited: Bool = false   // Track if user manually modified this session

    var phase: ProjectPhase?
    var completedTouchLog: TouchLog?     // Link when completed
    var generatedDetails: String?        // AI-generated practical steps (on-demand)

    init(
        id: UUID = UUID(),
        title: String,
        goal: String? = nil,
        estimatedMinutes: Int = 60,
        sequenceOrder: Int = 0,
        status: SessionStatus = .planned,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.estimatedMinutes = estimatedMinutes
        self.sequenceOrder = sequenceOrder
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var formattedDuration: String {
        if estimatedMinutes < 60 {
            return "~\(estimatedMinutes)m"
        } else if estimatedMinutes == 60 {
            return "~1h"
        } else {
            let hours = estimatedMinutes / 60
            let mins = estimatedMinutes % 60
            if mins == 0 {
                return "~\(hours)h"
            }
            return "~\(hours)h \(mins)m"
        }
    }

    var projectTitle: String? {
        phase?.project?.title
    }

    var phaseName: String? {
        phase?.title
    }

    var mentalRule: String? {
        phase?.mentalRule
    }

    // MARK: - Actions

    func markComplete(with touchLog: TouchLog? = nil) {
        status = .completed
        completedAt = Date()
        completedTouchLog = touchLog
    }

    func markSkipped() {
        status = .skipped
        completedAt = Date()
    }
}
