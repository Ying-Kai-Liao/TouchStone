import Foundation
import SwiftData

// MARK: - Day State Service

/// DayState computes the current state of the day based on stones (fixed events)
/// and water (projects that flow around them).
/// Uses a "liquid scheduler" algorithm to suggest work sessions.
/// Respects day contexts (holidays, vacations) that affect capacity.
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
    private(set) var activeRules: [Rule] = []  // Store active rules for meal display
    private(set) var activeContexts: [DayContext] = []  // Store active day contexts

    init(date: Date = Date()) {
        self.date = calendar.startOfDay(for: date)
    }

    // MARK: - Capacity Tracking

    /// Total minutes of stones (fixed events) today
    var stoneMinutesToday: Int {
        stoneInstances.reduce(0) { $0 + $1.event.durationMinutes }
    }

    /// Base capacity after context adjustments (before stone deduction)
    var contextAdjustedCapacity: Int {
        let baseCapacity = prefs.dailyProductiveMinutes
        let multiplier = activeContexts.effectiveCapacity(for: date)
        return Int(Double(baseCapacity) * multiplier)
    }

    /// Available minutes for project work (capacity - stones - context adjustments)
    var availableMinutes: Int {
        max(0, contextAdjustedCapacity - stoneMinutesToday)
    }

    /// Whether user has reached their daily productive capacity
    var hasReachedCapacity: Bool {
        minutesTouchedToday >= availableMinutes && availableMinutes > 0
    }

    /// The strictest work mode from active contexts
    var effectiveWorkMode: DayContextWorkMode {
        activeContexts.strictestWorkMode(for: date)
    }

    /// Fixed task description if in fixed mode
    var fixedTaskDescription: String? {
        activeContexts.fixedTask(for: date)
    }

    /// Whether sessions should be suppressed (no work or fixed mode)
    var shouldSuppressSessions: Bool {
        let mode = effectiveWorkMode
        return mode == .none || mode == .fixed
    }

    // MARK: - Compute Day State

    func compute(stones: [StoneEvent], projects: [Project], rules: [Rule] = [], contexts: [DayContext] = []) {
        // 1. Get today's stone instances
        stoneInstances = stones
            .filter { $0.occursOn(date: date) }
            .map { StoneEventInstance(event: $0, on: date) }
            .sorted { $0.startTime < $1.startTime }

        // 2. Store active rules that apply to this date for meal display
        activeRules = rules.filter { $0.appliesTo(date: date) }

        // 3. Store active contexts that apply to this date
        activeContexts = contexts.active(for: date)

        // 4. Calculate free time slots (considering rules)
        freeSlots = calculateFreeSlots(rules: rules)

        // 5. Calculate total minutes touched for the computed date
        // Use self.date (already start of day) to ensure future days show full schedule
        minutesTouchedToday = projects.flatMap { $0.touchLogs }
            .filter { calendar.startOfDay(for: $0.timestamp) == date }
            .reduce(0) { $0 + $1.durationMinutes }

        // 6. Generate suggested sessions (pour water into slots)
        // Skip if work mode is "none" or "fixed"
        if shouldSuppressSessions {
            suggestedSessions = []
        } else {
            suggestedSessions = generateSuggestedSessions(projects: projects)
        }

        // 7. Generate unified workflow items (merge stones, waters, meals, and contexts)
        workflowItems = generateWorkflowItems(projects: projects)

        // 8. Generate day message based on load, capacity, and contexts
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

    // MARK: - Commit Work Day Decision

    /// Record the user's decision to work today.
    /// No longer persists scheduled sessions - just uses suggestions.
    func commitWorkDay(to dayPlan: DayPlan, context: ModelContext, stones: [StoneEvent], projects: [Project]) {
        // 1. First compute the day state to generate suggestions
        compute(stones: stones, projects: projects)

        // 2. Create or update backlog for capacity tracking
        let backlog = dayPlan.backlog ?? Backlog(date: date)
        backlog.dayPlan = dayPlan
        backlog.resetAllocation()
        if dayPlan.backlog == nil {
            context.insert(backlog)
            dayPlan.backlog = backlog
        }

        // 3. Mark day plan as committed
        dayPlan.startedAt = Date()
    }

    // MARK: - Liquid Scheduler (Pour Water into Slots)

    private func generateSuggestedSessions(projects: [Project]) -> [SuggestedSession] {
        // Filter to active, non-completed projects only
        let activeProjects = projects.filter { project in
            guard project.isActive else { return false }
            if project.totalPlannedMinutes > 0 {
                return project.remainingHours > 0
            }
            return true
        }
        guard !activeProjects.isEmpty else { return [] }

        // Calculate remaining capacity
        let remainingCapacity = max(0, availableMinutes - minutesTouchedToday)
        let minSession = prefs.sessionMinMinutes
        guard remainingCapacity >= minSession else { return [] }

        // Count available session slots
        let sessionSlots = remainingCapacity / prefs.sessionMaxMinutes

        // Check for crunch mode - projects within threshold days of deadline
        let crunchProjects = detectCrunchProjects(activeProjects, date: date)

        // If in crunch mode, skip diversity and fill all slots with crunch projects
        if !crunchProjects.isEmpty {
            return scheduleCrunchMode(
                crunchProjects: crunchProjects,
                remainingCapacity: remainingCapacity
            )
        }

        // Normal mode: Apply priority scoring and diversity constraints
        let weeklyProgress = WeeklyProgress(for: date)
        let prioritized = calculatePriorityScores(
            projects: activeProjects,
            weeklyProgress: weeklyProgress
        )

        // Apply diversity constraints (2-3 distinct projects)
        let diverseProjects = applyDiversityConstraints(
            prioritizedProjects: prioritized,
            sessionSlots: sessionSlots,
            minProjects: prefs.minProjectsPerDay,
            maxProjects: prefs.maxProjectsPerDay
        )

        // Pour projects into time slots
        return pourSessionsIntoSlots(
            projects: diverseProjects,
            remainingCapacity: remainingCapacity
        )
    }

    // MARK: - Crunch Mode Detection

    /// Detect projects that are within crunch threshold of their deadline
    private func detectCrunchProjects(_ projects: [Project], date: Date) -> [Project] {
        let threshold = prefs.crunchThresholdDays

        // Find projects in crunch mode (within threshold AND have remaining work)
        let crunchProjects = projects.filter { project in
            project.isInCrunchMode(from: date, threshold: threshold) || project.isOverdue
        }

        // Sort by deadline (earliest first), then by remaining hours (most first for ties)
        return crunchProjects.sorted { p1, p2 in
            let d1 = p1.daysUntilDeadline ?? Int.max
            let d2 = p2.daysUntilDeadline ?? Int.max
            if d1 != d2 { return d1 < d2 }
            return p1.remainingHours > p2.remainingHours
        }
    }

    /// Schedule in crunch mode - all time goes to crunch project(s)
    private func scheduleCrunchMode(crunchProjects: [Project], remainingCapacity: Int) -> [SuggestedSession] {
        // Create a project list that repeats crunch projects to fill all slots
        var projectsToSchedule: [Project] = []
        let maxSessions = 6 // Cap to prevent infinite loops

        // Interleave crunch projects if there are multiple
        var projectIndex = 0
        while projectsToSchedule.count < maxSessions {
            projectsToSchedule.append(crunchProjects[projectIndex % crunchProjects.count])
            projectIndex += 1
        }

        return pourSessionsIntoSlots(
            projects: projectsToSchedule,
            remainingCapacity: remainingCapacity
        )
    }

    // MARK: - Priority Scoring

    /// Calculate priority scores for projects using multi-factor formula
    private func calculatePriorityScores(
        projects: [Project],
        weeklyProgress: WeeklyProgress
    ) -> [(Project, Double)] {
        return projects.map { project in
            let score = calculateProjectPriority(project: project, weeklyProgress: weeklyProgress)
            return (project, score)
        }.sorted { $0.1 > $1.1 } // Higher priority first
    }

    /// Calculate individual project priority score
    /// Factors: remaining work (0-50), urgency (0-200), due this week (0-75), staleness (0-50), weekly adjustment (-25 to +25)
    private func calculateProjectPriority(project: Project, weeklyProgress: WeeklyProgress) -> Double {
        var total: Double = 0

        // 1. Remaining work score (0-50)
        let remainingWorkScore: Double = project.remainingHours > 0 ? 50 : 0
        total += remainingWorkScore

        // 2. Deadline urgency score (0-200)
        let urgencyScore = project.urgencyScore(from: date)
        total += urgencyScore

        // 3. Due this week bonus (0-75)
        if prefs.dueThisWeekPriorityBoost && project.isDueThisWeek(from: date) {
            total += 75
        }

        // 4. Staleness score (0-50, capped)
        let daysSinceTouch = project.daysSinceLastTouch ?? 100
        let stalenessScore = min(50, Double(daysSinceTouch) * 5)
        total += stalenessScore

        // 5. Weekly catch-up adjustment (-25 to +25)
        let progress = weeklyProgress.calculateProgress(
            for: project,
            dailyCapacity: prefs.dailyProductiveHours,
            date: date
        )
        // If behind on weekly target, boost priority; if ahead, reduce
        let weeklyAdjustment: Double
        if progress.targetHoursThisWeek > 0 {
            let progressRatio = progress.completedHoursThisWeek / progress.targetHoursThisWeek
            if progressRatio < 0.8 {
                // Behind: boost by up to +25
                weeklyAdjustment = 25 * (1 - progressRatio)
            } else if progressRatio > 1.2 {
                // Ahead: reduce by up to -25
                weeklyAdjustment = -25 * min(1, (progressRatio - 1))
            } else {
                weeklyAdjustment = 0
            }
        } else {
            weeklyAdjustment = 0
        }
        total += weeklyAdjustment

        return total
    }

    // MARK: - Diversity Constraints

    /// Apply diversity constraints to select 2-3 projects for the day
    private func applyDiversityConstraints(
        prioritizedProjects: [(Project, Double)],
        sessionSlots: Int,
        minProjects: Int,
        maxProjects: Int
    ) -> [Project] {
        // Get unique projects (sorted by priority)
        let uniqueProjects = prioritizedProjects.map { $0.0 }

        // Determine how many distinct projects to schedule
        let availableProjects = uniqueProjects.count
        let targetProjects = min(maxProjects, max(1, min(minProjects, availableProjects)))

        // Select top N distinct projects
        let selectedProjects = Array(uniqueProjects.prefix(targetProjects))

        // Calculate max sessions each project actually needs based on remaining work
        let sessionDurationHours = Double(prefs.sessionMaxMinutes) / 60.0
        func maxSessionsNeeded(for project: Project) -> Int {
            guard project.totalPlannedMinutes > 0 else { return 3 } // Unlimited for unplanned projects
            let needed = Int(ceil(Double(project.remainingHours) / sessionDurationHours))
            return max(1, min(needed, 3)) // At least 1, at most 3
        }

        // Distribute sessions across selected projects (interleaved for cognitive variety)
        var result: [Project] = []

        // Round-robin distribution respecting each project's actual needs
        var sessionCounts: [UUID: Int] = [:]
        var projectIndex = 0
        let maxTotalSessions = max(sessionSlots, 1)

        while result.count < maxTotalSessions {
            let project = selectedProjects[projectIndex % selectedProjects.count]
            let currentCount = sessionCounts[project.id, default: 0]
            let maxForThisProject = maxSessionsNeeded(for: project)

            if currentCount < maxForThisProject {
                result.append(project)
                sessionCounts[project.id] = currentCount + 1
            }

            projectIndex += 1

            // Safety: check if all projects have reached their max sessions
            let allProjectsMaxed = selectedProjects.allSatisfy { p in
                sessionCounts[p.id, default: 0] >= maxSessionsNeeded(for: p)
            }
            if allProjectsMaxed {
                break
            }

            // Safety: break if we've cycled too many times
            if projectIndex >= selectedProjects.count * 10 {
                break
            }
        }

        return result
    }

    // MARK: - Session Pouring

    /// Pour projects into available time slots
    private func pourSessionsIntoSlots(projects: [Project], remainingCapacity: Int) -> [SuggestedSession] {
        let minSession = prefs.sessionMinMinutes
        var usableSlots = freeSlots.filter { $0.durationMinutes >= minSession }

        // Track accumulated work time for break insertion
        var accumulatedWorkMinutes = 0
        let workInterval = prefs.workIntervalMinutes
        let breakDuration = prefs.restDurationMinutes
        let breaksEnabled = prefs.restBetweenSessionsEnabled

        // Adjust slots to start from now if we're viewing today
        let now = Date()
        let isToday = calendar.isDateInToday(date)

        if isToday {
            usableSlots = usableSlots.compactMap { slot -> TimeSlot? in
                if slot.end <= now { return nil }
                if slot.start >= now { return slot }
                return TimeSlot(start: now, end: slot.end)
            }.filter { $0.durationMinutes >= minSession }
        }

        var sessions: [SuggestedSession] = []
        var usedMinutes = 0
        var slotIndex = 0
        var currentSlotStart = usableSlots.first?.start ?? now

        for project in projects {
            guard usedMinutes < remainingCapacity else { break }
            guard slotIndex < usableSlots.count else { break }

            let slot = usableSlots[slotIndex]
            var remainingSlotMinutes = Int(slot.end.timeIntervalSince(currentSlotStart) / 60)

            // Check if we need to insert a break gap before this session
            if breaksEnabled && accumulatedWorkMinutes >= workInterval && accumulatedWorkMinutes > 0 {
                currentSlotStart = currentSlotStart.addingTimeInterval(Double(breakDuration) * 60)
                remainingSlotMinutes = Int(slot.end.timeIntervalSince(currentSlotStart) / 60)
                accumulatedWorkMinutes = 0

                if remainingSlotMinutes < minSession {
                    slotIndex += 1
                    if slotIndex < usableSlots.count {
                        currentSlotStart = usableSlots[slotIndex].start
                        remainingSlotMinutes = usableSlots[slotIndex].durationMinutes
                    } else {
                        break
                    }
                }
            }

            let sessionDuration = optimalSessionDuration(
                availableMinutes: min(remainingSlotMinutes, remainingCapacity - usedMinutes),
                minDuration: prefs.sessionMinMinutes,
                maxDuration: prefs.sessionMaxMinutes
            )

            if let duration = sessionDuration {
                let sessionSlot = TimeSlot(
                    start: currentSlotStart,
                    end: currentSlotStart.addingTimeInterval(Double(duration) * 60)
                )
                let session = SuggestedSession(
                    project: project,
                    timeSlot: sessionSlot,
                    suggestedMinutes: duration
                )
                sessions.append(session)
                usedMinutes += duration
                accumulatedWorkMinutes += duration

                currentSlotStart = currentSlotStart.addingTimeInterval(Double(duration) * 60)

                let neededForNext = breaksEnabled && accumulatedWorkMinutes >= workInterval
                    ? minSession + breakDuration
                    : minSession
                let remainingInSlot = Int(slot.end.timeIntervalSince(currentSlotStart) / 60)
                if remainingInSlot < neededForNext {
                    slotIndex += 1
                    if slotIndex < usableSlots.count {
                        currentSlotStart = usableSlots[slotIndex].start
                    }
                }
            } else {
                slotIndex += 1
                if slotIndex < usableSlots.count {
                    currentSlotStart = usableSlots[slotIndex].start
                }
            }
        }

        return sessions
    }

    /// Calculate optimal session duration using smart fit algorithm.
    /// Returns nil if available time is less than minimum duration.
    private func optimalSessionDuration(availableMinutes: Int, minDuration: Int, maxDuration: Int) -> Int? {
        // Not enough time for minimum session
        if availableMinutes < minDuration { return nil }

        // Plenty of time - use max duration
        if availableMinutes >= maxDuration { return maxDuration }

        // Smart fit: use available space (fits perfectly)
        return availableMinutes
    }

    // MARK: - Workflow Items Generation

    private func generateWorkflowItems(projects: [Project]) -> [WorkflowItem] {
        var items: [WorkflowItem] = []
        let now = Date()
        let isToday = calendar.isDateInToday(date)

        // 1. Add all stone instances as workflow items
        for instance in stoneInstances {
            let status: WorkflowItemStatus
            if isToday {
                // For today, calculate status based on current time
                if instance.endTime <= now {
                    status = .completed
                } else if instance.startTime <= now && now < instance.endTime {
                    status = .inProgress
                } else {
                    status = .upcoming
                }
            } else {
                // For future dates, all items are upcoming
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

        // 3. Add meal rules as workflow items (lunch, dinner badges)
        for rule in activeRules {
            if let blocked = rule.blockedRange(for: date) {
                let status: WorkflowItemStatus
                if isToday {
                    if blocked.end <= now {
                        status = .completed
                    } else if blocked.start <= now && now < blocked.end {
                        status = .inProgress
                    } else {
                        status = .upcoming
                    }
                } else {
                    status = .upcoming
                }

                let item = WorkflowItem(
                    type: .meal(rule),
                    startTime: blocked.start,
                    endTime: blocked.end,
                    status: status
                )
                items.append(item)
            }
        }

        // 4. Sort all items chronologically
        items.sort { $0.startTime < $1.startTime }

        // 5. Insert breathing spaces and flow prep between items
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

                // Check if we've accumulated enough work to warrant a rest
                if accumulatedWorkMinutes + sessionMinutes >= workInterval && accumulatedWorkMinutes > 0 {
                    // Only insert rest if there's enough gap before this item
                    if let lastItem = result.last {
                        let restEnd = lastItem.endTime.addingTimeInterval(Double(restDuration) * 60)

                        // FIX: Only insert rest if it doesn't overlap with the current item
                        if restEnd <= item.startTime {
                            let restItem = WorkflowItem(
                                type: .rest(minutes: restDuration),
                                startTime: lastItem.endTime,
                                endTime: restEnd,
                                status: .suggested
                            )
                            result.append(restItem)
                        }
                    }
                    // Reset accumulated time after rest (or skipped rest)
                    accumulatedWorkMinutes = 0
                }

                accumulatedWorkMinutes += sessionMinutes
            } else if item.isStone || item.isMeal {
                // Reset work accumulator when hitting a stone or meal (natural break)
                accumulatedWorkMinutes = 0
            }

            result.append(item)
        }

        return result
    }

    // MARK: - Free Time Calculation

    private func calculateFreeSlots(rules: [Rule] = []) -> [TimeSlot] {
        // Use working hours from preferences
        let dayStart = calendar.date(bySettingHour: prefs.workDayStartHour, minute: 0, second: 0, of: date)!
        let dayEnd = calendar.date(bySettingHour: prefs.workDayEndHour, minute: 0, second: 0, of: date)!

        // Combine stones with rules as blocked slots
        var blockedSlots: [(start: Date, end: Date)] = stoneInstances.map {
            ($0.startTime, $0.endTime)
        }

        // Add active rules that apply to this date
        for rule in rules {
            if let blocked = rule.blockedRange(for: date) {
                blockedSlots.append(blocked)
            }
            // Handle overnight rules (morning portion)
            if let morningBlocked = rule.morningBlockedRange(for: date) {
                blockedSlots.append(morningBlocked)
            }
        }

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
        // Check for active day contexts first
        if !activeContexts.isEmpty {
            return contextMessage()
        }

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

    private func contextMessage() -> String {
        guard let primaryContext = activeContexts.min(by: { $0.workMode.priority < $1.workMode.priority }) else {
            return "A balanced day ahead."
        }

        switch primaryContext.workMode {
        case .none:
            return "\(primaryContext.name) - Take the day off. Your stones are shown above."
        case .reduced:
            return "\(primaryContext.name) - Working at \(primaryContext.capacityPercent)% capacity today."
        case .fixed:
            if let task = primaryContext.fixedTaskDescription {
                return "\(primaryContext.name) - Focus on: \(task)"
            }
            return "\(primaryContext.name) - Working on a fixed task today."
        case .normal:
            return "\(primaryContext.name) - Full capacity with a gentle reminder."
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

// MARK: - Work Suggestion

/// A work suggestion generated by the liquid scheduler.
/// For phase-mode projects, includes the active phase.
/// For milestone-mode projects, includes the next milestone.
struct SuggestedSession: Identifiable {
    let id = UUID()
    let project: Project
    let timeSlot: TimeSlot
    let suggestedMinutes: Int

    /// The active phase for phase-mode projects
    var activePhase: ProjectPhase? {
        guard project.isPhaseMode else { return nil }
        return project.activePhase
    }

    /// The next milestone for milestone-mode projects
    var nextMilestone: Milestone? {
        guard project.isMilestoneMode else { return nil }
        return project.nextMilestone
    }

    /// Intention text for focus mode
    var intentionText: String {
        if let phase = activePhase {
            return phase.mentalRule ?? phase.title
        } else if let milestone = nextMilestone {
            return milestone.title
        }
        return project.title
    }

    var periodLabel: String {
        timeSlot.periodLabel
    }

    var timeRangeString: String {
        timeSlot.timeRangeString
    }
}
