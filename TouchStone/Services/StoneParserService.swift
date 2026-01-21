import Foundation

/// Service for parsing natural language into StoneEvent data using OpenAI
actor StoneParserService {

    /// Parsed stone event data from natural language
    struct ParsedStoneEvent: Codable {
        let title: String
        let startHour: Int          // 0-23
        let startMinute: Int        // 0-59
        let endHour: Int            // 0-23
        let endMinute: Int          // 0-59
        let recurrenceType: String  // none, daily, weekdays, weekends, weekly, custom
        let customDays: [Int]?      // For custom recurrence: 1=Sun, 2=Mon, ... 7=Sat
        let specificDate: String?   // ISO date string for one-time events (YYYY-MM-DD)
        let confidence: Double      // 0.0 to 1.0 confidence score

        /// Convert to RecurrenceType enum
        var recurrence: RecurrenceType {
            switch recurrenceType.lowercased() {
            case "daily": return .daily
            case "weekdays": return .weekdays
            case "weekends": return .weekends
            case "weekly": return .weekly
            case "custom": return .custom
            default: return .none
            }
        }

        /// Check if the parsed result is usable
        var isValid: Bool {
            !title.isEmpty && confidence > 0.5
        }
    }

    private let openAI = OpenAIClient()

    private var systemPrompt: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayDate = dateFormatter.string(from: Date())

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayName = dayFormatter.string(from: Date())

        return """
        You are a calendar event parser. Parse the user's natural language input into a structured stone event (fixed time block).

        Return a JSON object with these fields:
        - title: string - The event name/title (extract the main activity)
        - startHour: int - Start hour in 24-hour format (0-23)
        - startMinute: int - Start minute (0-59)
        - endHour: int - End hour in 24-hour format (0-23)
        - endMinute: int - End minute (0-59)
        - recurrenceType: string - One of: "none", "daily", "weekdays", "weekends", "weekly", "custom"
        - customDays: array of int or null - For custom recurrence, days where 1=Sunday, 2=Monday, ... 7=Saturday
        - specificDate: string or null - For one-time or weekly events, the date in YYYY-MM-DD format
        - confidence: float - Your confidence in the parsing (0.0 to 1.0)

        Rules:
        1. If no end time is specified, default to 1 hour after start
        2. If no AM/PM specified:
           - Hours 1-6 are assumed PM (13-18)
           - Hours 7-11 are assumed AM
           - Hour 12 is assumed PM (noon)
        3. For recurrence:
           - "every day", "daily" → "daily"
           - "weekdays", "Monday through Friday" → "weekdays"
           - "weekends", "Saturday and Sunday" → "weekends"
           - "every week", "weekly", "every [day name]" → "weekly"
           - Specific days mentioned → "custom" with customDays array
           - No recurrence mentioned → "none"
        4. For weekly events, try to determine the day from context
        5. Always extract the cleanest possible title

        Today's date is: \(todayDate)
        Current day of week: \(dayName)

        Examples:
        - "Team meeting at 10 AM" → title: "Team meeting", startHour: 10, endHour: 11, recurrence: "none"
        - "Lunch from 12 to 1 daily" → title: "Lunch", startHour: 12, endHour: 13, recurrence: "daily"
        - "Gym at 6 PM on weekdays" → title: "Gym", startHour: 18, endHour: 19, recurrence: "weekdays"
        - "Coffee with John tomorrow at 3" → title: "Coffee with John", startHour: 15, endHour: 16, recurrence: "none", specificDate: tomorrow's date
        - "Standup every Monday and Wednesday at 9:30" → title: "Standup", startHour: 9, startMinute: 30, recurrence: "custom", customDays: [2, 4]
        """
    }

    /// Parse natural language text into a structured stone event
    func parse(_ text: String) async throws -> ParsedStoneEvent {
        return try await openAI.chatJSON(
            systemPrompt: systemPrompt,
            userMessage: text,
            temperature: 0.3,
            responseType: ParsedStoneEvent.self
        )
    }

    /// Create a StoneEvent from parsed data
    @MainActor
    func createStoneEvent(from parsed: ParsedStoneEvent, defaultDate: Date = Date()) -> StoneEvent {
        let recurrence: RecurrencePattern
        switch parsed.recurrence {
        case .none:
            recurrence = .none
        case .daily:
            recurrence = .daily
        case .weekdays:
            recurrence = .weekdays
        case .weekends:
            recurrence = .weekends
        case .weekly:
            recurrence = .weekly
        case .custom:
            recurrence = .custom(days: parsed.customDays ?? [])
        }

        var specificDate: Date? = nil
        if parsed.recurrence == .none || parsed.recurrence == .weekly {
            if let dateStr = parsed.specificDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                specificDate = formatter.date(from: dateStr) ?? defaultDate
            } else {
                specificDate = defaultDate
            }
        }

        return StoneEvent(
            title: parsed.title,
            startHour: parsed.startHour,
            startMinute: parsed.startMinute,
            endHour: parsed.endHour,
            endMinute: parsed.endMinute,
            specificDate: specificDate,
            recurrence: recurrence
        )
    }
}
