import Foundation
import SwiftData
import SwiftUI

// MARK: - Day Context Type

/// Type of day context affecting scheduling
enum DayContextType: String, Codable, CaseIterable, Identifiable {
    case holiday
    case vacation
    case travel
    case event
    case personal
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .holiday: return "Holiday"
        case .vacation: return "Vacation"
        case .travel: return "Travel"
        case .event: return "Event"
        case .personal: return "Personal"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .holiday: return "gift"
        case .vacation: return "sun.max"
        case .travel: return "airplane"
        case .event: return "star"
        case .personal: return "person"
        case .custom: return "tag"
        }
    }

    var defaultColor: String {
        switch self {
        case .holiday: return "#FF6B6B"    // Red
        case .vacation: return "#4ECDC4"   // Teal
        case .travel: return "#45B7D1"     // Blue
        case .event: return "#96CEB4"      // Green
        case .personal: return "#FFEAA7"   // Yellow
        case .custom: return "#DDA0DD"     // Plum
        }
    }
}

// MARK: - Day Context Work Mode

/// How work is affected during this context
enum DayContextWorkMode: String, Codable, CaseIterable, Identifiable {
    case none       // No work (0% capacity), stones only
    case reduced    // Reduced capacity (use capacityPercent)
    case fixed      // Specific fixed task only
    case normal     // Badge only, full capacity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No Work"
        case .reduced: return "Reduced"
        case .fixed: return "Fixed Task"
        case .normal: return "Normal"
        }
    }

    var description: String {
        switch self {
        case .none: return "No sessions scheduled, only fixed events"
        case .reduced: return "Work at reduced capacity"
        case .fixed: return "Only show a specific fixed task"
        case .normal: return "Full capacity with badge indicator"
        }
    }

    var icon: String {
        switch self {
        case .none: return "moon.zzz"
        case .reduced: return "gauge.with.dots.needle.33percent"
        case .fixed: return "pin"
        case .normal: return "checkmark.circle"
        }
    }

    /// Priority for overlap handling (lower number = stricter)
    var priority: Int {
        switch self {
        case .none: return 0
        case .reduced: return 1
        case .fixed: return 2
        case .normal: return 3
        }
    }

    /// Color for UI display
    var color: Color {
        switch self {
        case .none: return DesignSystem.Colors.textTertiary
        case .reduced: return DesignSystem.Colors.warning
        case .fixed: return DesignSystem.Colors.accent
        case .normal: return DesignSystem.Colors.success
        }
    }
}

// MARK: - Day Context Model

/// A DayContext represents a day-level status (holiday, vacation, event) that spans
/// one or more days and affects work scheduling.
@Model
final class DayContext {
    var id: UUID = UUID()
    var name: String
    var startDate: Date              // Start of day (normalized)
    var endDate: Date                // End of day (inclusive)
    var typeRaw: String              // DayContextType raw value
    var workModeRaw: String          // DayContextWorkMode raw value
    var capacityPercent: Int = 50    // For reduced mode (0-100)
    var fixedTaskDescription: String? // For fixed mode
    var colorHex: String?
    var notes: String?
    var createdAt: Date = Date()

    init(
        name: String,
        startDate: Date,
        endDate: Date,
        type: DayContextType = .custom,
        workMode: DayContextWorkMode = .normal,
        capacityPercent: Int = 50,
        fixedTaskDescription: String? = nil,
        colorHex: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        // Normalize dates to start of day
        let calendar = Calendar.current
        self.startDate = calendar.startOfDay(for: startDate)
        self.endDate = calendar.startOfDay(for: endDate)
        self.typeRaw = type.rawValue
        self.workModeRaw = workMode.rawValue
        self.capacityPercent = capacityPercent
        self.fixedTaskDescription = fixedTaskDescription
        self.colorHex = colorHex ?? type.defaultColor
        self.notes = notes
        self.createdAt = Date()
    }

    // MARK: - Computed Properties

    var type: DayContextType {
        get { DayContextType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    var workMode: DayContextWorkMode {
        get { DayContextWorkMode(rawValue: workModeRaw) ?? .normal }
        set { workModeRaw = newValue.rawValue }
    }

    /// Duration in days (inclusive)
    var durationDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return days + 1 // Inclusive
    }

    /// Shared date formatter for efficient date range formatting
    private static let dateRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Human-readable date range string
    var dateRangeString: String {
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return Self.dateRangeFormatter.string(from: startDate)
        } else {
            return "\(Self.dateRangeFormatter.string(from: startDate)) - \(Self.dateRangeFormatter.string(from: endDate))"
        }
    }

    /// Short description for display
    var shortDescription: String {
        switch workMode {
        case .none:
            return "Day off"
        case .reduced:
            return "\(capacityPercent)% capacity"
        case .fixed:
            return fixedTaskDescription ?? "Fixed task"
        case .normal:
            return "Full capacity"
        }
    }

    // MARK: - Occurrence Check

    /// Check if this context applies to a given date
    func appliesTo(date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        return targetDay >= startDate && targetDay <= endDate
    }

    /// Get effective capacity multiplier (0.0 to 1.0)
    var capacityMultiplier: Double {
        switch workMode {
        case .none:
            return 0.0
        case .reduced:
            return Double(capacityPercent) / 100.0
        case .fixed:
            return 0.0 // Fixed mode shows only the fixed task
        case .normal:
            return 1.0
        }
    }
}

// MARK: - Helper Extensions

extension Array where Element == DayContext {
    /// Get contexts that apply to a specific date
    func active(for date: Date) -> [DayContext] {
        filter { $0.appliesTo(date: date) }
    }

    /// Get the strictest work mode from overlapping contexts
    /// Lower priority value = stricter (none > reduced > fixed > normal)
    func strictestWorkMode(for date: Date) -> DayContextWorkMode {
        let activeContexts = active(for: date)
        guard !activeContexts.isEmpty else { return .normal }

        return activeContexts
            .map { $0.workMode }
            .min { $0.priority < $1.priority } ?? .normal
    }

    /// Get effective capacity for a date considering all overlapping contexts
    /// Uses the strictest mode's capacity
    func effectiveCapacity(for date: Date) -> Double {
        let activeContexts = active(for: date)
        guard !activeContexts.isEmpty else { return 1.0 }

        // Find the context with the strictest work mode
        guard let strictestContext = activeContexts.min(by: { $0.workMode.priority < $1.workMode.priority }) else {
            return 1.0
        }

        return strictestContext.capacityMultiplier
    }

    /// Get the fixed task description if in fixed mode
    func fixedTask(for date: Date) -> String? {
        let activeContexts = active(for: date)
        let fixedContexts = activeContexts.filter { $0.workMode == .fixed }
        return fixedContexts.first?.fixedTaskDescription
    }
}
