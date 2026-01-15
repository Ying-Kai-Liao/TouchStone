import Foundation
import SwiftData

// MARK: - Stone Event Model

/// A StoneEvent represents a fixed, immovable time block.
/// These are "reality" - things that cannot be moved.
/// Examples: meetings, appointments, classes, meals, sleep.
@Model
final class StoneEvent {
    var id: UUID
    var title: String

    // Time (stored as components, not full Date, for recurring events)
    var startHour: Int      // 0-23
    var startMinute: Int    // 0-59
    var endHour: Int        // 0-23
    var endMinute: Int      // 0-59

    // For one-time events, the specific date
    var specificDate: Date?

    // Recurrence
    var recurrenceData: Data?  // Encoded RecurrencePattern

    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0,
        specificDate: Date? = nil,
        recurrence: RecurrencePattern = .none,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.specificDate = specificDate
        self.recurrenceData = try? JSONEncoder().encode(recurrence)
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    var recurrence: RecurrencePattern {
        get {
            guard let data = recurrenceData else { return .none }
            return (try? JSONDecoder().decode(RecurrencePattern.self, from: data)) ?? .none
        }
        set {
            recurrenceData = try? JSONEncoder().encode(newValue)
        }
    }

    var startTimeString: String {
        String(format: "%d:%02d %@",
               startHour > 12 ? startHour - 12 : (startHour == 0 ? 12 : startHour),
               startMinute,
               startHour >= 12 ? "PM" : "AM")
    }

    var endTimeString: String {
        String(format: "%d:%02d %@",
               endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour),
               endMinute,
               endHour >= 12 ? "PM" : "AM")
    }

    var timeRangeString: String {
        "\(startTimeString) - \(endTimeString)"
    }

    var durationMinutes: Int {
        let startTotal = startHour * 60 + startMinute
        let endTotal = endHour * 60 + endMinute
        return endTotal - startTotal
    }

    // MARK: - Occurrence Check

    /// Check if this event occurs on a given date
    func occursOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)  // 1 = Sunday

        switch recurrence.type {
        case .none:
            // One-time event - check specific date
            guard let specificDate = specificDate else { return false }
            return calendar.isDate(date, inSameDayAs: specificDate)

        case .daily:
            return true

        case .weekdays:
            return weekday >= 2 && weekday <= 6  // Mon-Fri

        case .weekends:
            return weekday == 1 || weekday == 7  // Sun or Sat

        case .weekly:
            // Check if same weekday as creation date
            guard let specificDate = specificDate else { return false }
            let eventWeekday = calendar.component(.weekday, from: specificDate)
            return weekday == eventWeekday

        case .custom:
            guard let days = recurrence.customDays else { return false }
            return days.contains(weekday)
        }
    }

    /// Get the actual start DateTime for a specific date
    func startDateTime(on date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = startHour
        components.minute = startMinute
        return calendar.date(from: components) ?? date
    }

    /// Get the actual end DateTime for a specific date
    func endDateTime(on date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = endHour
        components.minute = endMinute
        return calendar.date(from: components) ?? date
    }
}

// MARK: - Stone Event Instance (for display)

/// A resolved instance of a StoneEvent for a specific date
struct StoneEventInstance: Identifiable {
    let id: UUID
    let event: StoneEvent
    let date: Date
    let startTime: Date
    let endTime: Date

    init(event: StoneEvent, on date: Date) {
        self.id = UUID()
        self.event = event
        self.date = date
        self.startTime = event.startDateTime(on: date)
        self.endTime = event.endDateTime(on: date)
    }

    var title: String { event.title }
    var timeString: String { event.startTimeString }
}
