import Foundation
import SwiftData

// MARK: - Day State Service

/// DayState computes the current state of the day based on stones (fixed events)
/// and water (projects that flow around them).
@Observable
class DayState {
    let date: Date
    private let calendar = Calendar.current

    // Daily productive capacity (hardcoded for now, settings can come later)
    private let dailyProductiveMinutes: Int = 360  // 6 hours

    // Computed data
    private(set) var stoneInstances: [StoneEventInstance] = []
    private(set) var freeSlots: [TimeSlot] = []
    private(set) var dayMessage: String = ""
    private(set) var minutesTouchedToday: Int = 0

    init(date: Date = Date()) {
        self.date = calendar.startOfDay(for: date)
    }

    // MARK: - Capacity Tracking

    /// Total minutes of stones (fixed events) today
    var stoneMinutesToday: Int {
        stoneInstances.reduce(0) { $0 + $1.event.durationMinutes }
    }

    /// Available minutes for project work (capacity - stones)
    var availableMinutes: Int {
        max(0, dailyProductiveMinutes - stoneMinutesToday)
    }

    /// Whether user has reached their daily productive capacity
    var hasReachedCapacity: Bool {
        minutesTouchedToday >= availableMinutes && availableMinutes > 0
    }

    // MARK: - Compute Day State

    func compute(stones: [StoneEvent], projects: [Project]) {
        // 1. Get today's stone instances
        stoneInstances = stones
            .filter { $0.occursOn(date: date) }
            .map { StoneEventInstance(event: $0, on: date) }
            .sorted { $0.startTime < $1.startTime }

        // 2. Calculate free time slots
        freeSlots = calculateFreeSlots()

        // 3. Calculate total minutes touched today across all projects
        let today = calendar.startOfDay(for: Date())
        minutesTouchedToday = projects.flatMap { $0.touchLogs }
            .filter { calendar.startOfDay(for: $0.timestamp) == today }
            .reduce(0) { $0 + $1.durationMinutes }

        // 4. Generate day message based on load and capacity
        dayMessage = generateDayMessage()
    }

    // MARK: - Free Time Calculation

    private func calculateFreeSlots() -> [TimeSlot] {
        // Define working hours (9 AM - 9 PM for simplicity)
        let dayStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
        let dayEnd = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: date)!

        var slots: [TimeSlot] = []
        var currentTime = dayStart

        for stone in stoneInstances {
            // If there's free time before this stone
            if currentTime < stone.startTime {
                slots.append(TimeSlot(start: currentTime, end: stone.startTime))
            }
            // Move current time to after the stone
            currentTime = max(currentTime, stone.endTime)
        }

        // Add remaining time after last stone
        if currentTime < dayEnd {
            slots.append(TimeSlot(start: currentTime, end: dayEnd))
        }

        return slots
    }

    // MARK: - Day Message Generation

    private func generateDayMessage() -> String {
        // Check if user has done enough for today
        if hasReachedCapacity {
            return capacityReachedMessage()
        }

        let totalStoneMinutes = stoneInstances.reduce(0) { $0 + $1.event.durationMinutes }

        // Generate message based on stone load
        if stoneInstances.isEmpty {
            return "The day is open. You have space to think."
        } else if totalStoneMinutes < 120 {
            return "The schedule is light. You have space to think."
        } else if totalStoneMinutes < 300 {
            return "A balanced day ahead."
        } else {
            return "A full day. Be kind to yourself."
        }
    }

    private func capacityReachedMessage() -> String {
        let messages = [
            "You've done meaningful work today. Time to recharge.",
            "Good progress today. Your mind needs rest too.",
            "You've touched enough today. Go easy on yourself.",
            "Solid day. Consider stepping away for a bit.",
            "You've put in good work. Take care of yourself."
        ]
        // Use a seed based on today's date for consistent daily message
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        return messages[dayOfYear % messages.count]
    }

    // MARK: - Current Time Context

    var currentTimeSlot: TimeSlot? {
        let now = Date()
        return freeSlots.first { $0.contains(now) }
    }

    var nextStone: StoneEventInstance? {
        let now = Date()
        return stoneInstances.first { $0.startTime > now }
    }

    var isInStone: Bool {
        let now = Date()
        return stoneInstances.contains { $0.startTime <= now && now < $0.endTime }
    }

    var currentStone: StoneEventInstance? {
        let now = Date()
        return stoneInstances.first { $0.startTime <= now && now < $0.endTime }
    }
}

// MARK: - Time Slot

struct TimeSlot: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    var periodLabel: String {
        let hour = Calendar.current.component(.hour, from: start)
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }
}
