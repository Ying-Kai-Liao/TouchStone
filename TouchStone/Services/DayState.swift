import Foundation
import SwiftData

// MARK: - Day State Service

/// DayState computes the current state of the day based on stones (fixed events)
/// and water (projects that flow around them).
@Observable
class DayState {
    let date: Date
    private let calendar = Calendar.current

    // Computed data
    private(set) var stoneInstances: [StoneEventInstance] = []
    private(set) var freeSlots: [TimeSlot] = []
    private(set) var dayMessage: String = ""

    init(date: Date = Date()) {
        self.date = calendar.startOfDay(for: date)
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

        // 3. Generate day message based on load
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
        let totalStoneMinutes = stoneInstances.reduce(0) { $0 + $1.event.durationMinutes }
        let freeMinutes = freeSlots.reduce(0) { $0 + $1.durationMinutes }

        // Check current time of day
        let hour = calendar.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default: timeOfDay = "night"
        }

        // Generate message based on load
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
