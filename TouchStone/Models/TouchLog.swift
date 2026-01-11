import Foundation
import SwiftData

// MARK: - Touch Log Model

/// A TouchLog records when a project was "touched" - acknowledging work done.
/// This is not about tracking exact time, but about acknowledging effort.
/// Duration is approximate (~30min, ~1h, ~2h) - no need to be exact.
@Model
final class TouchLog {
    var id: UUID
    var timestamp: Date             // When the touch was logged
    var durationMinutes: Int        // Approximate duration
    var note: String?               // Optional reflection

    var project: Project?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        durationMinutes: Int = 60,
        note: String? = nil,
        project: Project? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.durationMinutes = durationMinutes
        self.note = note
        self.project = project
    }

    // MARK: - Computed Properties

    var dateOnly: Date {
        Calendar.current.startOfDay(for: timestamp)
    }

    var formattedDuration: String {
        switch durationMinutes {
        case ..<45: return "~30m"
        case 45..<75: return "~1h"
        case 75..<105: return "~1.5h"
        case 105..<150: return "~2h"
        default: return "~\(durationMinutes / 60)h"
        }
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }

    var projectTitle: String {
        project?.title ?? "Untitled"
    }
}
