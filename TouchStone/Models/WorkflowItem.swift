import Foundation

// MARK: - Workflow Item Types

/// Represents different types of items in the daily workflow timeline
enum WorkflowItemType {
    case stone(StoneEventInstance)           // Fixed event (meeting, appointment)
    case water(SuggestedSession)             // Flexible work session
    case breathingSpace(minutes: Int)        // Short break between activities
    case flowPrep(minutes: Int)              // Preparation time before work
    case rest(minutes: Int)                  // Break between work sessions
    case meal(Rule)                          // Meal time (lunch, dinner) from rules
}

/// Status of a workflow item
enum WorkflowItemStatus {
    case completed      // User finished this item
    case inProgress     // Currently active
    case upcoming       // In the future
    case overdue        // Past due, not completed
    case suggested      // Suggestion only (waters)
}

// MARK: - Workflow Item

/// A unified item in the daily workflow timeline.
/// Merges stones (fixed events) and waters (flexible sessions) into a single chronological stream.
struct WorkflowItem: Identifiable {
    let id: UUID
    let type: WorkflowItemType
    let startTime: Date
    let endTime: Date
    var status: WorkflowItemStatus

    init(type: WorkflowItemType, startTime: Date, endTime: Date, status: WorkflowItemStatus = .upcoming) {
        self.id = UUID()
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
    }

    // MARK: - Computed Properties

    var title: String {
        switch type {
        case .stone(let instance):
            return instance.title
        case .water(let session):
            return session.project.title
        case .breathingSpace:
            return "Breathing Space"
        case .flowPrep:
            return "Flow State Prep"
        case .rest(let minutes):
            return "Break · \(minutes)m"
        case .meal(let rule):
            return rule.title
        }
    }

    var subtitle: String? {
        switch type {
        case .stone:
            return nil
        case .water(let session):
            return session.project.activePhase?.title ?? session.project.currentPhase
        case .breathingSpace:
            return nil
        case .flowPrep:
            return nil
        case .rest:
            return "Take a short break"
        case .meal:
            return nil
        }
    }

    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTime)) — \(formatter.string(from: endTime))"
    }

    var isStone: Bool {
        if case .stone = type { return true }
        return false
    }

    var isWater: Bool {
        if case .water = type { return true }
        return false
    }

    var isBreathingSpace: Bool {
        if case .breathingSpace = type { return true }
        return false
    }

    var isFlowPrep: Bool {
        if case .flowPrep = type { return true }
        return false
    }

    var isRest: Bool {
        if case .rest = type { return true }
        return false
    }

    var isMeal: Bool {
        if case .meal = type { return true }
        return false
    }

    var rule: Rule? {
        if case .meal(let rule) = type {
            return rule
        }
        return nil
    }

    var project: Project? {
        if case .water(let session) = type {
            return session.project
        }
        return nil
    }

    var suggestedSession: SuggestedSession? {
        if case .water(let session) = type {
            return session
        }
        return nil
    }

    var stoneInstance: StoneEventInstance? {
        if case .stone(let instance) = type {
            return instance
        }
        return nil
    }
}
