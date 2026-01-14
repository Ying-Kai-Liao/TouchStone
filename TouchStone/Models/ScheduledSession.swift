import Foundation
import SwiftData

// MARK: - Session Status

enum ScheduledSessionStatus: String, Codable {
    case pending    // Not yet started
    case completed  // User touched/completed the session
    case skipped    // Time passed without completion
}

// MARK: - Scheduled Session Model

/// A persisted work session that has been locked into the day's schedule.
/// Created when user clicks "Let's go" and remains fixed for the day.
@Model
final class ScheduledSession {
    var id: UUID = UUID()
    var scheduledStart: Date
    var scheduledEnd: Date
    var sequenceOrder: Int = 0
    var statusRaw: String = "pending"
    var completedAt: Date?
    var createdAt: Date = Date()

    // Relationships
    var dayPlan: DayPlan?
    var project: Project?
    var touchLog: TouchLog?

    // MARK: - Computed Properties

    var status: ScheduledSessionStatus {
        get { ScheduledSessionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    /// Duration in minutes
    var durationMinutes: Int {
        Int(scheduledEnd.timeIntervalSince(scheduledStart) / 60)
    }

    /// Whether this session is currently active (now is within scheduled time)
    var isActive: Bool {
        let now = Date()
        return now >= scheduledStart && now < scheduledEnd
    }

    /// Whether this session's time has passed
    var isPast: Bool {
        Date() >= scheduledEnd
    }

    /// Whether this session is in the future
    var isFuture: Bool {
        Date() < scheduledStart
    }

    /// Formatted time range string
    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: scheduledStart)) - \(formatter.string(from: scheduledEnd))"
    }

    /// Project title (safe access)
    var projectTitle: String {
        project?.title ?? "Untitled"
    }

    // MARK: - Initialization

    init(project: Project, start: Date, end: Date, order: Int) {
        self.project = project
        self.scheduledStart = start
        self.scheduledEnd = end
        self.sequenceOrder = order
    }

    // MARK: - Methods

    /// Mark session as completed and link to touch log
    func complete(with touchLog: TouchLog? = nil) {
        self.status = .completed
        self.completedAt = Date()
        self.touchLog = touchLog
    }

    /// Mark session as skipped
    func skip() {
        self.status = .skipped
    }

    /// Check if this session conflicts with a time range
    func conflicts(with start: Date, end: Date) -> Bool {
        // Two ranges conflict if one starts before the other ends
        return scheduledStart < end && scheduledEnd > start
    }

    /// Reschedule to a new time slot (preserving duration)
    func reschedule(to newStart: Date) {
        let duration = scheduledEnd.timeIntervalSince(scheduledStart)
        scheduledStart = newStart
        scheduledEnd = newStart.addingTimeInterval(duration)
    }
}
