import Foundation

/// Parses natural language speech into StoneEvent components
struct SpeechParser {

    struct ParsedStone {
        var title: String
        var startHour: Int?
        var startMinute: Int
        var endHour: Int?
        var endMinute: Int
        var recurrence: RecurrenceType

        var isValid: Bool {
            !title.isEmpty && startHour != nil
        }
    }

    /// Parse speech text like:
    /// - "Team meeting at 10 AM"
    /// - "Lunch from 12 to 1"
    /// - "Standup at 9:30 AM every day"
    /// - "Gym at 6 PM on weekdays"
    static func parse(_ text: String) -> ParsedStone {
        let lowercased = text.lowercased()

        var result = ParsedStone(
            title: "",
            startHour: nil,
            startMinute: 0,
            endHour: nil,
            endMinute: 0,
            recurrence: .none
        )

        // Extract recurrence
        result.recurrence = parseRecurrence(lowercased)

        // Extract times
        let times = parseTimes(lowercased)
        if let start = times.start {
            result.startHour = start.hour
            result.startMinute = start.minute
        }
        if let end = times.end {
            result.endHour = end.hour
            result.endMinute = end.minute
        } else if let startHour = result.startHour {
            // Default to 1 hour duration
            result.endHour = (startHour + 1) % 24
            result.endMinute = result.startMinute
        }

        // Extract title (remove time and recurrence words)
        result.title = parseTitle(text, lowercased: lowercased)

        return result
    }

    // MARK: - Time Parsing

    private struct TimeComponent {
        let hour: Int
        let minute: Int
    }

    private static func parseTimes(_ text: String) -> (start: TimeComponent?, end: TimeComponent?) {
        var start: TimeComponent?
        var end: TimeComponent?

        // Pattern: "from X to Y" or "X to Y"
        let fromToPattern = #"(?:from\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\s*(?:to|-)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?"#
        if let match = text.range(of: fromToPattern, options: .regularExpression) {
            let matchStr = String(text[match])
            let times = extractTimePair(from: matchStr)
            start = times.0
            end = times.1
        }

        // Pattern: "at X" (single time)
        if start == nil {
            let atPattern = #"at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?"#
            if let match = text.range(of: atPattern, options: .regularExpression) {
                let matchStr = String(text[match])
                start = extractSingleTime(from: matchStr)
            }
        }

        // Fallback: just find any time pattern
        if start == nil {
            let timePattern = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)"#
            if let match = text.range(of: timePattern, options: .regularExpression) {
                let matchStr = String(text[match])
                start = extractSingleTime(from: matchStr)
            }
        }

        return (start, end)
    }

    private static func extractSingleTime(from text: String) -> TimeComponent? {
        let pattern = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        guard let hourRange = Range(match.range(at: 1), in: text),
              var hour = Int(text[hourRange]) else {
            return nil
        }

        var minute = 0
        if let minuteRange = Range(match.range(at: 2), in: text) {
            minute = Int(text[minuteRange]) ?? 0
        }

        if let periodRange = Range(match.range(at: 3), in: text) {
            let period = text[periodRange].lowercased()
            if period.contains("p") && hour < 12 {
                hour += 12
            } else if period.contains("a") && hour == 12 {
                hour = 0
            }
        } else {
            // No AM/PM - guess based on hour
            if hour >= 1 && hour <= 6 {
                hour += 12 // Assume PM for 1-6
            }
        }

        return TimeComponent(hour: hour, minute: minute)
    }

    private static func extractTimePair(from text: String) -> (TimeComponent?, TimeComponent?) {
        let parts = text.components(separatedBy: CharacterSet(charactersIn: "to-"))
        guard parts.count >= 2 else {
            return (extractSingleTime(from: text), nil)
        }

        let start = extractSingleTime(from: parts[0])
        var end = extractSingleTime(from: parts[1])

        // Adjust end time if start is PM and end has no period
        if let s = start, let e = end, s.hour >= 12 && e.hour < 12 && !parts[1].lowercased().contains("am") {
            end = TimeComponent(hour: e.hour + 12, minute: e.minute)
        }

        return (start, end)
    }

    // MARK: - Recurrence Parsing

    private static func parseRecurrence(_ text: String) -> RecurrenceType {
        if text.contains("every day") || text.contains("daily") || text.contains("each day") {
            return .daily
        }
        if text.contains("weekday") || text.contains("monday through friday") || text.contains("mon to fri") {
            return .weekdays
        }
        if text.contains("weekend") {
            return .weekends
        }
        if text.contains("every week") || text.contains("weekly") || text.contains("each week") {
            return .weekly
        }
        return .none
    }

    // MARK: - Title Extraction

    private static func parseTitle(_ original: String, lowercased: String) -> String {
        var title = original

        // Remove time patterns
        let timePatterns = [
            #"(?:from\s+)?\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?\s*(?:to|-)\s*\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?"#,
            #"at\s+\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?"#,
            #"\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)"#,
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                title = regex.stringByReplacingMatches(in: title, range: NSRange(title.startIndex..., in: title), withTemplate: "")
            }
        }

        // Remove recurrence words
        let recurrenceWords = ["every day", "daily", "each day", "weekdays", "weekends", "every week", "weekly", "each week", "monday through friday", "mon to fri", "on"]
        for word in recurrenceWords {
            title = title.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }

        // Clean up
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.replacingOccurrences(of: "  ", with: " ")

        // Capitalize first letter
        if let first = title.first {
            title = first.uppercased() + title.dropFirst()
        }

        return title
    }
}
