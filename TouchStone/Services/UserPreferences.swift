import Foundation
import SwiftUI

// MARK: - Theme Color Option

enum ThemeColorOption: String, CaseIterable, Identifiable {
    case sage = "sage"
    case ocean = "ocean"
    case lavender = "lavender"
    case coral = "coral"
    case gold = "gold"
    case slate = "slate"

    var id: String { rawValue }

    /// The main accent color for this theme
    var accentColor: Color {
        switch self {
        case .sage: return Color(red: 0.65, green: 0.78, blue: 0.65)
        case .ocean: return Color(red: 0.55, green: 0.70, blue: 0.80)
        case .lavender: return Color(red: 0.70, green: 0.60, blue: 0.80)
        case .coral: return Color(red: 0.85, green: 0.55, blue: 0.55)
        case .gold: return Color(red: 0.85, green: 0.75, blue: 0.50)
        case .slate: return Color(red: 0.60, green: 0.65, blue: 0.70)
        }
    }

    /// A muted version of the accent
    var accentMuted: Color {
        switch self {
        case .sage: return Color(red: 0.55, green: 0.68, blue: 0.55)
        case .ocean: return Color(red: 0.45, green: 0.60, blue: 0.70)
        case .lavender: return Color(red: 0.60, green: 0.50, blue: 0.70)
        case .coral: return Color(red: 0.75, green: 0.45, blue: 0.45)
        case .gold: return Color(red: 0.75, green: 0.65, blue: 0.40)
        case .slate: return Color(red: 0.50, green: 0.55, blue: 0.60)
        }
    }

    var displayName: String {
        switch self {
        case .sage: return "Sage"
        case .ocean: return "Ocean"
        case .lavender: return "Lavender"
        case .coral: return "Coral"
        case .gold: return "Gold"
        case .slate: return "Slate"
        }
    }
}

// MARK: - Legacy Accent Color Option (deprecated)

enum AccentColorOption: String, CaseIterable, Identifiable {
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case mint = "mint"
    case teal = "teal"
    case cyan = "cyan"
    case indigo = "indigo"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .indigo: return .indigo
        }
    }

    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .mint: return "Mint"
        case .teal: return "Teal"
        case .cyan: return "Cyan"
        case .indigo: return "Indigo"
        }
    }
}

// MARK: - User Preferences

/// Centralized preferences manager using UserDefaults for persistence.
/// Uses @Observable for SwiftUI reactivity.
@Observable
class UserPreferences {
    static let shared = UserPreferences()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let dailyProductiveHours = "dailyProductiveHours"
        static let workDayStartHour = "workDayStartHour"
        static let workDayEndHour = "workDayEndHour"
        static let sessionMinMinutes = "sessionMinMinutes"
        static let sessionMaxMinutes = "sessionMaxMinutes"
        static let restBetweenSessionsEnabled = "restBetweenSessionsEnabled"
        static let workIntervalMinutes = "workIntervalMinutes"
        static let restDurationMinutes = "restDurationMinutes"
        static let appLanguage = "appLanguage"
        static let accentColor = "accentColor"
        static let themeColor = "themeColor"
        static let deadlineBufferPercent = "deadlineBufferPercent"
    }

    // MARK: - Productive Hours

    /// Target productive hours per day (default: 6 hours)
    var dailyProductiveHours: Int {
        didSet { defaults.set(dailyProductiveHours, forKey: Keys.dailyProductiveHours) }
    }

    /// Computed daily productive minutes
    var dailyProductiveMinutes: Int {
        dailyProductiveHours * 60
    }

    // MARK: - Working Hours

    /// Hour when work day starts (default: 9 AM)
    var workDayStartHour: Int {
        didSet { defaults.set(workDayStartHour, forKey: Keys.workDayStartHour) }
    }

    /// Hour when work day ends (default: 9 PM / 21:00)
    var workDayEndHour: Int {
        didSet { defaults.set(workDayEndHour, forKey: Keys.workDayEndHour) }
    }

    // MARK: - Session Duration

    /// Minimum session length in minutes (default: 45)
    var sessionMinMinutes: Int {
        didSet { defaults.set(sessionMinMinutes, forKey: Keys.sessionMinMinutes) }
    }

    /// Maximum session length in minutes (default: 90)
    var sessionMaxMinutes: Int {
        didSet { defaults.set(sessionMaxMinutes, forKey: Keys.sessionMaxMinutes) }
    }

    // MARK: - Rest Breaks

    /// Whether to add rest breaks after work intervals
    var restBetweenSessionsEnabled: Bool {
        didSet { defaults.set(restBetweenSessionsEnabled, forKey: Keys.restBetweenSessionsEnabled) }
    }

    /// Work interval before taking a rest (default: 60 minutes)
    var workIntervalMinutes: Int {
        didSet { defaults.set(workIntervalMinutes, forKey: Keys.workIntervalMinutes) }
    }

    /// Duration of rest breaks in minutes (default: 15)
    var restDurationMinutes: Int {
        didSet { defaults.set(restDurationMinutes, forKey: Keys.restDurationMinutes) }
    }

    // MARK: - Deadline Buffer

    /// Percentage of days before deadline to reserve as buffer (default: 20%)
    var deadlineBufferPercent: Int {
        didSet { defaults.set(deadlineBufferPercent, forKey: Keys.deadlineBufferPercent) }
    }

    // MARK: - Language (Future)

    /// App language setting (default: follow system)
    var appLanguage: String {
        didSet { defaults.set(appLanguage, forKey: Keys.appLanguage) }
    }

    // MARK: - Theme Color

    /// Selected theme color option (default: sage)
    var themeColorOption: ThemeColorOption {
        didSet { defaults.set(themeColorOption.rawValue, forKey: Keys.themeColor) }
    }

    /// Computed accent color for SwiftUI (from theme)
    var accentColor: Color {
        themeColorOption.accentColor
    }

    /// Computed muted accent color
    var accentMuted: Color {
        themeColorOption.accentMuted
    }

    // MARK: - Legacy Accent Color (deprecated, kept for compatibility)

    /// Selected accent color option (deprecated - use themeColorOption)
    var accentColorOption: AccentColorOption {
        didSet { defaults.set(accentColorOption.rawValue, forKey: Keys.accentColor) }
    }

    // MARK: - Initialization

    init() {
        // Load from UserDefaults with defaults
        self.dailyProductiveHours = defaults.object(forKey: Keys.dailyProductiveHours) as? Int ?? 6
        self.workDayStartHour = defaults.object(forKey: Keys.workDayStartHour) as? Int ?? 9
        self.workDayEndHour = defaults.object(forKey: Keys.workDayEndHour) as? Int ?? 21
        self.sessionMinMinutes = defaults.object(forKey: Keys.sessionMinMinutes) as? Int ?? 45
        self.sessionMaxMinutes = defaults.object(forKey: Keys.sessionMaxMinutes) as? Int ?? 90
        self.restBetweenSessionsEnabled = defaults.object(forKey: Keys.restBetweenSessionsEnabled) as? Bool ?? true
        self.workIntervalMinutes = defaults.object(forKey: Keys.workIntervalMinutes) as? Int ?? 60
        self.restDurationMinutes = defaults.object(forKey: Keys.restDurationMinutes) as? Int ?? 15
        self.deadlineBufferPercent = defaults.object(forKey: Keys.deadlineBufferPercent) as? Int ?? 20
        self.appLanguage = defaults.string(forKey: Keys.appLanguage) ?? "system"

        // Load theme color
        if let colorString = defaults.string(forKey: Keys.themeColor),
           let color = ThemeColorOption(rawValue: colorString) {
            self.themeColorOption = color
        } else {
            self.themeColorOption = .sage
        }

        // Load legacy accent color (for compatibility)
        if let colorString = defaults.string(forKey: Keys.accentColor),
           let color = AccentColorOption(rawValue: colorString) {
            self.accentColorOption = color
        } else {
            self.accentColorOption = .teal
        }
    }

    // MARK: - Convenience Methods

    /// Get the work day boundaries for a given date
    func workDayBounds(for date: Date) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        guard let start = calendar.date(bySettingHour: workDayStartHour, minute: 0, second: 0, of: date),
              let end = calendar.date(bySettingHour: workDayEndHour, minute: 0, second: 0, of: date) else {
            return nil
        }
        return (start, end)
    }
}
