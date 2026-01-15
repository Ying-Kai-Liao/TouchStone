import Foundation
import SwiftData

// MARK: - Rule Model

/// A Rule represents a recurring blocked time slot.
/// Used for lunch, dinner, sleep, and other personal time blocks.
/// These are treated like "soft stones" - the scheduler respects them
/// but they're managed separately from calendar events.
@Model
final class Rule {
    var id: UUID = UUID()
    var title: String
    var startHour: Int          // 0-23
    var startMinute: Int        // 0-59
    var endHour: Int            // 0-23
    var endMinute: Int          // 0-59
    var recurrenceData: Data?   // Encoded RecurrencePattern
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(
        title: String,
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0,
        recurrence: RecurrencePattern = .daily,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.title = title
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.recurrenceData = try? JSONEncoder().encode(recurrence)
        self.isActive = isActive
        self.createdAt = Date()
    }

    // MARK: - Computed Properties

    var recurrence: RecurrencePattern {
        get {
            guard let data = recurrenceData else { return .daily }
            return (try? JSONDecoder().decode(RecurrencePattern.self, from: data)) ?? .daily
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

    var recurrenceDescription: String {
        switch recurrence.type {
        case .none: return "One-time"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .weekly: return "Weekly"
        case .custom:
            guard let days = recurrence.customDays, !days.isEmpty else { return "Custom" }
            let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let selected = days.compactMap { day -> String? in
                let index = day - 1 // Convert 1-indexed to 0-indexed
                return index >= 0 && index < 7 ? dayNames[index] : nil
            }
            return selected.joined(separator: ", ")
        }
    }

    // MARK: - Occurrence Check

    /// Check if this rule applies to a given date
    func appliesTo(date: Date) -> Bool {
        guard isActive else { return false }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday

        switch recurrence.type {
        case .none:
            return false // Rules should generally recur
        case .daily:
            return true
        case .weekdays:
            return weekday >= 2 && weekday <= 6 // Mon-Fri
        case .weekends:
            return weekday == 1 || weekday == 7 // Sun or Sat
        case .weekly:
            return true // Weekly rules apply on all days (could enhance later)
        case .custom:
            guard let days = recurrence.customDays else { return false }
            return days.contains(weekday)
        }
    }

    /// Get the blocked time range for a specific date
    func blockedRange(for date: Date) -> (start: Date, end: Date)? {
        guard appliesTo(date: date) else { return nil }

        let calendar = Calendar.current
        guard let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date),
              let end = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: date) else {
            return nil
        }

        // Handle overnight rules (e.g., sleep 22:00 - 07:00)
        // For overnight, we block from start to midnight on this day
        // The morning portion is handled when querying for that day
        if end <= start {
            let midnight = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
            return (start, midnight)
        }

        return (start, end)
    }

    /// Get the morning blocked range for overnight rules
    func morningBlockedRange(for date: Date) -> (start: Date, end: Date)? {
        guard appliesTo(date: date) else { return nil }

        let calendar = Calendar.current
        guard let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date),
              let end = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: date) else {
            return nil
        }

        // Only return morning portion for overnight rules
        if end <= start {
            let dayStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date)!
            return (dayStart, end)
        }

        return nil
    }
}

// MARK: - Rule Seeding

/// Seeds default rules if none exist
func seedDefaultRules(context: ModelContext) {
    let descriptor = FetchDescriptor<Rule>()
    guard (try? context.fetchCount(descriptor)) == 0 else { return }

    // Lunch: 12:00 - 13:00 daily
    let lunch = Rule(
        title: "Lunch",
        startHour: 12,
        startMinute: 0,
        endHour: 13,
        endMinute: 0,
        recurrence: .daily
    )
    context.insert(lunch)

    // Dinner: 18:00 - 19:00 daily
    let dinner = Rule(
        title: "Dinner",
        startHour: 18,
        startMinute: 0,
        endHour: 19,
        endMinute: 0,
        recurrence: .daily
    )
    context.insert(dinner)
}
