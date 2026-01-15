import Foundation

// MARK: - Recurrence Pattern

/// Represents different types of recurring schedules
enum RecurrenceType: String, Codable {
    case none           // One-time event
    case daily          // Every day
    case weekdays       // Monday - Friday
    case weekends       // Saturday - Sunday
    case weekly         // Same day each week
    case custom         // Specific days
}

/// Configuration for recurring events/rules
struct RecurrencePattern: Codable, Equatable {
    var type: RecurrenceType
    var customDays: [Int]?  // 1 = Sunday, 2 = Monday, ... 7 = Saturday

    static let none = RecurrencePattern(type: .none)
    static let daily = RecurrencePattern(type: .daily)
    static let weekdays = RecurrencePattern(type: .weekdays)
    static let weekends = RecurrencePattern(type: .weekends)
    static let weekly = RecurrencePattern(type: .weekly)

    static func custom(days: [Int]) -> RecurrencePattern {
        RecurrencePattern(type: .custom, customDays: days)
    }
}
