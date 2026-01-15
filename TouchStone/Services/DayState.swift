import Foundation
import SwiftData

// MARK: - Day State Service

/// DayState computes the current state of the day based on stones (fixed events)
/// and water (projects that flow around them).
/// Uses a "liquid scheduler" algorithm to suggest work sessions.
@Observable
class DayState {
    let date: Date
    private let calendar = Calendar.current
    private let prefs = UserPreferences.shared

    // Computed data
    private(set) var stoneInstances: [StoneEventInstance] = []
    private(set) var freeSlots: [TimeSlot] = []
    private(set) var suggestedSessions: [SuggestedSession] = []
    private(set) var workflowItems: [WorkflowItem] = []
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
        max(0, prefs.dailyProductiveMinutes - stoneMinutesToday)
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

        // 4. Generate suggested sessions (pour water into slots)
        suggestedSessions = generateSuggestedSessions(projects: projects)

        // 5. Generate unified workflow items (merge stones and waters)
        workflowItems = generateWorkflowItems(projects: projects)

        // 6. Generate day message based on load and capacity
        dayMessage = generateDayMessage()
    }

    /// Compute only stones (fixed events) for rest days.
    /// User declined to work today, so we only show reality without suggestions.
    func computeStonesOnly(stones: [StoneEvent]) {
        // 1. Get today's stone instances
        stoneInstances = stones
            .filter { $0.occursOn(date: date) }
            .map { StoneEventInstance(event: $0, on: date) }
            .sorted { $0.startTime < $1.startTime }

        // 2. Clear water-related data
        freeSlots = []
        suggestedSessions = []
        minutesTouchedToday = 0

        // 3. Generate workflow items for stones only
        let now = Date()
        workflowItems = stoneInstances.map { instance in
            let status: WorkflowItemStatus
            if instance.endTime <= now {
                status = .completed
            } else if instance.startTime <= now && now < instance.endTime {
                status = .inProgress
            } else {
                status = .upcoming
            }

            return WorkflowItem(
                type: .stone(instance),
                startTime: instance.startTime,
                endTime: instance.endTime,
                status: status
            )
        }

        // 4. Set rest day message
        dayMessage = "Taking it easy today. Your stones are shown above."
    }

    // MARK: - Commit Schedule to Database

    /// Generate and persist the day's schedule when user clicks "Let's go".
    /// This locks in the schedule for the day.
    func commitSchedule(to dayPlan: DayPlan, context: ModelContext, stones: [StoneEvent], projects: [Project]) {
        // 1. First compute the day state to generate suggestions
        compute(stones: stones, projects: projects)

        // 2. Clear any existing scheduled sessions
        for session in dayPlan.scheduledSessions {
            context.delete(session)
        }

        // 3. Create or update backlog
        let backlog = dayPlan.backlog ?? Backlog(date: date)
        backlog.dayPlan = dayPlan
        backlog.resetAllocation()
        if dayPlan.backlog == nil {
            context.insert(backlog)
            dayPlan.backlog = backlog
        }

        // 4. Convert suggested sessions to persisted ScheduledSessions
        for (index, suggestion) in suggestedSessions.enumerated() {
            let scheduled = ScheduledSession(
                project: suggestion.project,
                start: suggestion.timeSlot.start,
                end: suggestion.timeSlot.end,
                order: index
            )
            scheduled.dayPlan = dayPlan
            context.insert(scheduled)

            // Track allocation in backlog (1 hour per session)
            backlog.allocate(hours: 1)
        }
    }

    // MARK: - Load from Persisted Schedule

    /// Load workflow items from a persisted DayPlan schedule.
    /// Used when user has already clicked "Let's go" and schedule is locked in.
    func loadFromPersistedSchedule(dayPlan: DayPlan, stones: [StoneEvent]) {
        // 1. Load stones as usual
        stoneInstances = stones
            .filter { $0.occursOn(date: date) }
            .map { StoneEventInstance(event: $0, on: date) }
            .sorted { $0.startTime < $1.startTime }

        // 2. Calculate free slots (for reference)
        freeSlots = calculateFreeSlots()

        // 3. Clear ephemeral suggested sessions (we're using persisted ones)
        suggestedSessions = []

        // 4. Generate workflow items from persisted sessions + stones
        workflowItems = generateWorkflowFromPersisted(
            stones: stoneInstances,
            sessions: dayPlan.sortedSessions
        )

        // 5. Calculate minutes touched today
        let today = calendar.startOfDay(for: Date())
        minutesTouchedToday = dayPlan.scheduledSessions
            .filter { $0.status == .completed }
            .reduce(0) { $0 + $1.durationMinutes }

        // 6. Generate day message
        dayMessage = generateDayMessage()
    }

    /// Generate workflow items from persisted scheduled sessions
    private func generateWorkflowFromPersisted(stones: [StoneEventInstance], sessions: [ScheduledSession]) -> [WorkflowItem] {
        var items: [WorkflowItem] = []
        let now = Date()

        // 1. Add all stone instances as workflow items
        for instance in stones {
            let status: WorkflowItemStatus
            if instance.endTime <= now {
                status = .completed
            } else if instance.startTime <= now && now < instance.endTime {
                status = .inProgress
            } else {
                status = .upcoming
            }

            let item = WorkflowItem(
                type: .stone(instance),
                startTime: instance.startTime,
                endTime: instance.endTime,
                status: status
            )
            items.append(item)
        }

        // 2. Add persisted sessions as workflow items
        for session in sessions {
            // Map ScheduledSession status to WorkflowItemStatus
            let status: WorkflowItemStatus
            switch session.status {
            case .completed:
                status = .completed
            case .skipped:
                status = .overdue
            case .pending:
                if session.isActive {
                    status = .inProgress
                } else if session.isPast {
                    status = .overdue
                } else {
                    status = .suggested
                }
            }

            // Create a SuggestedSession wrapper for the workflow item
            let timeSlot = TimeSlot(start: session.scheduledStart, end: session.scheduledEnd)
            if let project = session.project {
                let suggestedSession = SuggestedSession(
                    project: project,
                    timeSlot: timeSlot,
                    suggestedMinutes: session.durationMinutes
                )

                let item = WorkflowItem(
                    type: .water(suggestedSession),
                    startTime: session.scheduledStart,
                    endTime: session.scheduledEnd,
                    status: status
                )
                items.append(item)
            }
        }

        // 3. Sort all items chronologically
        items.sort { $0.startTime < $1.startTime }

        // 4. Insert breathing spaces and flow prep between items
        items = insertTransitionItems(items: items)

        return items
    }

    // MARK: - Auto-Skip Expired Sessions

    /// Mark sessions as skipped if their time has passed without completion.
    /// Call this periodically or when viewing the day.
    static func autoSkipExpiredSessions(dayPlan: DayPlan) {
        let now = Date()
        for session in dayPlan.scheduledSessions {
            if session.status == .pending && session.scheduledEnd < now {
                session.status = .skipped
            }
        }
    }

    // MARK: - Handle New Stones (Auto-Adjust)

    /// Adjust schedule when a new stone (meeting) conflicts with existing sessions.
    /// Moves affected sessions to after the stone.
    static func adjustScheduleForNewStone(dayPlan: DayPlan, stoneStart: Date, stoneEnd: Date) {
        for session in dayPlan.scheduledSessions where session.status == .pending {
            if session.conflicts(with: stoneStart, end: stoneEnd) {
                // Reschedule to start after the stone
                session.reschedule(to: stoneEnd)
            }
        }
        // Note: This simple approach may create overlaps if multiple sessions are affected.
        // A more sophisticated approach would re-run the full scheduling algorithm.
    }

    // MARK: - Liquid Scheduler (Pour Water into Slots)

    private func generateSuggestedSessions(projects: [Project]) -> [SuggestedSession] {
        // Filter to active, non-completed projects only
        // A project is completed when it has planned hours and remaining hours is 0
        let activeProjects = projects.filter { project in
            guard project.isActive else { return false }
            // If project has planned hours, check if there's remaining work
            if project.totalPlannedMinutes > 0 {
                return project.remainingHours > 0
            }
            // Projects without planned hours are always included
            return true
        }
        guard !activeProjects.isEmpty else { return [] }

        // Sort projects by priority (staleness + remaining work)
        let prioritized = activeProjects
            .map { project -> (Project, Int) in
                let staleness = project.daysSinceLastTouch ?? 100 // Never touched = high priority
                let hasRemainingWork = project.remainingHours > 0
                // Priority score: staleness * 10 + (has remaining work ? 50 : 0)
                let priority = staleness * 10 + (hasRemainingWork ? 50 : 0)
                return (project, priority)
            }
            .sorted { $0.1 > $1.1 } // Higher priority first
            .map { $0.0 }

        // Calculate remaining capacity
        let remainingCapacity = max(0, availableMinutes - minutesTouchedToday)
        guard remainingCapacity >= 30 else { return [] } // Need at least 30 min

        var sessions: [SuggestedSession] = []
        var usedMinutes = 0
        var slotIndex = 0
        var usableSlots = freeSlots.filter { $0.durationMinutes >= 30 }

        // Adjust slots to start from now if we're in the middle of the day
        let now = Date()
        usableSlots = usableSlots.compactMap { slot -> TimeSlot? in
            if slot.end <= now { return nil } // Slot already passed
            if slot.start >= now { return slot } // Slot is in future
            // Truncate slot to start from now
            return TimeSlot(start: now, end: slot.end)
        }.filter { $0.durationMinutes >= 30 }

        // Pour projects into slots - track current position within slot
        var currentSlotStart = usableSlots.first?.start ?? now

        for project in prioritized {
            guard usedMinutes < remainingCapacity else { break }
            guard slotIndex < usableSlots.count else { break }

            let slot = usableSlots[slotIndex]
            let remainingSlotMinutes = Int(slot.end.timeIntervalSince(currentSlotStart) / 60)
            let sessionDuration = min(prefs.defaultSessionMinutes, remainingSlotMinutes, remainingCapacity - usedMinutes)

            if sessionDuration >= 30 {
                // Create a time slot for this specific session
                let sessionSlot = TimeSlot(
                    start: currentSlotStart,
                    end: currentSlotStart.addingTimeInterval(Double(sessionDuration) * 60)
                )
                let session = SuggestedSession(
                    project: project,
                    timeSlot: sessionSlot,
                    suggestedMinutes: sessionDuration
                )
                sessions.append(session)
                usedMinutes += sessionDuration

                // Move current position forward
                currentSlotStart = currentSlotStart.addingTimeInterval(Double(sessionDuration) * 60)

                // Move to next slot if this one is consumed
                if currentSlotStart >= slot.end.addingTimeInterval(-15 * 60) {
                    slotIndex += 1
                    if slotIndex < usableSlots.count {
                        currentSlotStart = usableSlots[slotIndex].start
                    }
                }
            }
        }

        return sessions
    }

    // MARK: - Workflow Items Generation

    private func generateWorkflowItems(projects: [Project]) -> [WorkflowItem] {
        var items: [WorkflowItem] = []
        let now = Date()

        // 1. Add all stone instances as workflow items
        for instance in stoneInstances {
            let status: WorkflowItemStatus
            if instance.endTime <= now {
                status = .completed
            } else if instance.startTime <= now && now < instance.endTime {
                status = .inProgress
            } else {
                status = .upcoming
            }

            let item = WorkflowItem(
                type: .stone(instance),
                startTime: instance.startTime,
                endTime: instance.endTime,
                status: status
            )
            items.append(item)
        }

        // 2. Add suggested sessions as workflow items with time slots
        for session in suggestedSessions {
            let sessionEnd = session.timeSlot.start.addingTimeInterval(Double(session.suggestedMinutes) * 60)
            let status: WorkflowItemStatus = .suggested

            let item = WorkflowItem(
                type: .water(session),
                startTime: session.timeSlot.start,
                endTime: sessionEnd,
                status: status
            )
            items.append(item)
        }

        // 3. Sort all items chronologically
        items.sort { $0.startTime < $1.startTime }

        // 4. Insert breathing spaces and flow prep between items
        items = insertTransitionItems(items: items)

        return items
    }

    private func insertTransitionItems(items: [WorkflowItem]) -> [WorkflowItem] {
        guard !items.isEmpty else { return items }
        guard prefs.restBetweenSessionsEnabled else { return items }

        var result: [WorkflowItem] = []
        var accumulatedWorkMinutes = 0
        let workInterval = prefs.workIntervalMinutes
        let restDuration = prefs.restDurationMinutes

        for item in items {
            // Track work time for water (work) sessions
            if item.isWater {
                let sessionMinutes = item.durationMinutes

                // Check if adding this session would exceed the work interval
                if accumulatedWorkMinutes + sessionMinutes >= workInterval && accumulatedWorkMinutes > 0 {
                    // Insert rest break before this session
                    if let lastItem = result.last {
                        let restItem = WorkflowItem(
                            type: .rest(minutes: restDuration),
                            startTime: lastItem.endTime,
                            endTime: lastItem.endTime.addingTimeInterval(Double(restDuration) * 60),
                            status: .suggested
                        )
                        result.append(restItem)
                    }
                    // Reset accumulated time after rest
                    accumulatedWorkMinutes = 0
                }

                accumulatedWorkMinutes += sessionMinutes
            }

            result.append(item)
        }

        return result
    }

    // MARK: - Free Time Calculation

    private func calculateFreeSlots() -> [TimeSlot] {
        // Use working hours from preferences
        let dayStart = calendar.date(bySettingHour: prefs.workDayStartHour, minute: 0, second: 0, of: date)!
        let dayEnd = calendar.date(bySettingHour: prefs.workDayEndHour, minute: 0, second: 0, of: date)!

        // Combine stones with daily rules (lunch/dinner) as blocked slots
        var blockedSlots: [(start: Date, end: Date)] = stoneInstances.map {
            ($0.startTime, $0.endTime)
        }

        // Add lunch/dinner from preferences
        blockedSlots.append(contentsOf: prefs.blockedSlots(for: date))

        // Sort by start time
        blockedSlots.sort { $0.start < $1.start }

        // Calculate free slots around all blocked times
        var slots: [TimeSlot] = []
        var currentTime = dayStart

        for blocked in blockedSlots {
            // Skip blocks outside working hours
            if blocked.end <= dayStart || blocked.start >= dayEnd {
                continue
            }

            // Clamp block to working hours
            let blockStart = max(blocked.start, dayStart)
            let blockEnd = min(blocked.end, dayEnd)

            // If there's free time before this block
            if currentTime < blockStart {
                slots.append(TimeSlot(start: currentTime, end: blockStart))
            }
            // Move current time to after the block
            currentTime = max(currentTime, blockEnd)
        }

        // Add remaining time after last block
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

// MARK: - Suggested Session

/// A suggested work session generated by the liquid scheduler.
/// Users can tap to "touch" the project and log time.
struct SuggestedSession: Identifiable {
    let id = UUID()
    let project: Project
    let timeSlot: TimeSlot
    let suggestedMinutes: Int

    var periodLabel: String {
        timeSlot.periodLabel
    }

    var timeRangeString: String {
        timeSlot.timeRangeString
    }
}
