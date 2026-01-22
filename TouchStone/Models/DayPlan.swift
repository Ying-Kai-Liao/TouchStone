import Foundation
import SwiftData

// MARK: - Day Plan Model

/// DayPlan tracks the user's daily work intention.
/// Records whether the user wants to work today and when they started.
/// The allocation shown is just a suggestion - what matters is actual touches.
@Model
final class DayPlan {
    var id: UUID
    var date: Date                    // Calendar date (start of day)
    var createdAt: Date               // When the plan was created
    var startedAt: Date?              // When user confirmed they want to work
    var wantsToWork: Bool?            // nil = not answered, true = yes, false = no

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Backlog.dayPlan)
    var backlog: Backlog?

    init(date: Date = Date()) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.createdAt = Date()
        self.startedAt = nil
        self.wantsToWork = nil
    }

    // MARK: - Computed Properties

    /// Whether the user has made a decision for this day
    var hasDecided: Bool {
        wantsToWork != nil
    }

    /// Whether the user confirmed they want to work today
    var isWorkDay: Bool {
        wantsToWork == true
    }

    /// Whether the user declined to work today
    var isRestDay: Bool {
        wantsToWork == false
    }

    /// Formatted start time string (e.g., "9:30 AM")
    var startTimeString: String? {
        guard let startedAt = startedAt else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startedAt)
    }

    /// Remaining capacity hours from the backlog
    var remainingCapacity: Int {
        backlog?.remainingHours ?? 0
    }
}
