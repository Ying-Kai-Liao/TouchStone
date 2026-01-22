import Foundation

// MARK: - Widget Data Model

/// Lightweight data structure for widget display.
/// This is synced from the main app to the widget via App Groups.
struct WidgetData: Codable {
    let date: Date
    let currentStatus: CurrentStatus
    let nextStone: StoneInfo?
    let suggestedProject: ProjectInfo?
    let todayStats: TodayStats
    let updatedAt: Date

    static let empty = WidgetData(
        date: Date(),
        currentStatus: .free(until: nil),
        nextStone: nil,
        suggestedProject: nil,
        todayStats: TodayStats(touchCount: 0, touchedMinutes: 0, capacityMinutes: 360, stonesCount: 0),
        updatedAt: Date()
    )
}

// MARK: - Current Status

enum CurrentStatus: Codable {
    case inStone(StoneInfo)
    case free(until: Date?)

    var displayText: String {
        switch self {
        case .inStone(let stone):
            return stone.title
        case .free(until: let date):
            if let date = date {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Free until \(formatter.string(from: date))"
            }
            return "Free"
        }
    }

    var isInStone: Bool {
        if case .inStone = self { return true }
        return false
    }
}

// MARK: - Stone Info

struct StoneInfo: Codable, Identifiable {
    let id: UUID
    let title: String
    let startTime: Date
    let endTime: Date

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }

    var timeUntil: String {
        let now = Date()
        if startTime <= now {
            return "now"
        }
        let interval = startTime.timeIntervalSince(now)
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "in \(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "in \(hours)h"
        }
        return "in \(hours)h \(remainingMinutes)m"
    }

    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
}

// MARK: - Project Info

struct ProjectInfo: Codable, Identifiable {
    let id: UUID
    let title: String
    let daysSinceTouch: Int?
    let completedHours: Int
    let plannedHours: Int
    let currentPhase: String?
    let hasDeadline: Bool
    let daysUntilDeadline: Int?

    var stalenessText: String? {
        guard let days = daysSinceTouch else { return "Never touched" }
        switch days {
        case 0: return nil // Don't show if touched today
        case 1: return "Yesterday"
        case 2...7: return "\(days) days ago"
        default: return "\(days) days ago"
        }
    }

    var progressText: String {
        if plannedHours > 0 {
            return "\(completedHours)/\(plannedHours)h"
        }
        return "\(completedHours)h"
    }

    var hasProgress: Bool {
        plannedHours > 0
    }

    var progress: Double {
        guard plannedHours > 0 else { return 0 }
        return min(1.0, Double(completedHours) / Double(plannedHours))
    }
}

// MARK: - Today Stats

struct TodayStats: Codable {
    let touchCount: Int
    let touchedMinutes: Int
    let capacityMinutes: Int
    let stonesCount: Int

    var touchedHours: Double {
        Double(touchedMinutes) / 60.0
    }

    var capacityHours: Double {
        Double(capacityMinutes) / 60.0
    }

    var progress: Double {
        guard capacityMinutes > 0 else { return 0 }
        return min(1.0, Double(touchedMinutes) / Double(capacityMinutes))
    }

    var remainingMinutes: Int {
        max(0, capacityMinutes - touchedMinutes)
    }

    var remainingHours: Double {
        Double(remainingMinutes) / 60.0
    }
}

// MARK: - Widget Data Manager

class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let suiteName = "group.touchstone.widget"
    private let dataKey = "widgetData"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    func save(_ data: WidgetData) {
        guard let defaults = sharedDefaults else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: dataKey)
        }
    }

    func load() -> WidgetData {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: dataKey),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .empty
        }
        return decoded
    }
}
