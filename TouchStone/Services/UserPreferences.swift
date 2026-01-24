import Foundation
import SwiftUI

// MARK: - Language Option

enum LanguageOption: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "System")
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        }
    }

    var icon: String {
        switch self {
        case .system: return "globe"
        case .english: return "a.circle"
        case .traditionalChinese: return "character.zh"
        }
    }

    /// The locale identifier for this language
    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .traditionalChinese: return "zh-Hant"
        }
    }
}

// MARK: - Appearance Mode Option

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Theme Color Option

enum ThemeColorOption: String, CaseIterable, Identifiable {
    case sage = "sage"
    case ocean = "ocean"
    case lavender = "lavender"
    case coral = "coral"
    case gold = "gold"
    case slate = "slate"

    var id: String { rawValue }

    /// Helper to check appearance mode
    private var isDarkMode: Bool {
        switch UserPreferences.shared.appearanceMode {
        case .dark: return true
        case .light: return false
        case .system: return true
        }
    }

    /// The main accent color for this theme (adapts to light/dark mode)
    var accentColor: Color {
        if isDarkMode {
            // Dark mode: lighter, softer colors
            switch self {
            case .sage: return Color(red: 0.65, green: 0.78, blue: 0.65)
            case .ocean: return Color(red: 0.55, green: 0.70, blue: 0.80)
            case .lavender: return Color(red: 0.70, green: 0.60, blue: 0.80)
            case .coral: return Color(red: 0.85, green: 0.55, blue: 0.55)
            case .gold: return Color(red: 0.85, green: 0.75, blue: 0.50)
            case .slate: return Color(red: 0.60, green: 0.65, blue: 0.70)
            }
        } else {
            // Light mode: deeper, more saturated colors for contrast
            switch self {
            case .sage: return Color(red: 0.35, green: 0.55, blue: 0.40)
            case .ocean: return Color(red: 0.25, green: 0.50, blue: 0.65)
            case .lavender: return Color(red: 0.50, green: 0.40, blue: 0.65)
            case .coral: return Color(red: 0.75, green: 0.35, blue: 0.35)
            case .gold: return Color(red: 0.70, green: 0.55, blue: 0.25)
            case .slate: return Color(red: 0.40, green: 0.45, blue: 0.52)
            }
        }
    }

    /// A muted version of the accent
    var accentMuted: Color {
        if isDarkMode {
            switch self {
            case .sage: return Color(red: 0.55, green: 0.68, blue: 0.55)
            case .ocean: return Color(red: 0.45, green: 0.60, blue: 0.70)
            case .lavender: return Color(red: 0.60, green: 0.50, blue: 0.70)
            case .coral: return Color(red: 0.75, green: 0.45, blue: 0.45)
            case .gold: return Color(red: 0.75, green: 0.65, blue: 0.40)
            case .slate: return Color(red: 0.50, green: 0.55, blue: 0.60)
            }
        } else {
            switch self {
            case .sage: return Color(red: 0.45, green: 0.60, blue: 0.50)
            case .ocean: return Color(red: 0.35, green: 0.55, blue: 0.70)
            case .lavender: return Color(red: 0.55, green: 0.48, blue: 0.68)
            case .coral: return Color(red: 0.78, green: 0.45, blue: 0.45)
            case .gold: return Color(red: 0.75, green: 0.60, blue: 0.35)
            case .slate: return Color(red: 0.48, green: 0.52, blue: 0.58)
            }
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
        static let appearanceMode = "appearanceMode"
        static let deadlineBufferPercent = "deadlineBufferPercent"
        // Deadline-aware scheduling settings
        static let minProjectsPerDay = "minProjectsPerDay"
        static let maxProjectsPerDay = "maxProjectsPerDay"
        static let crunchThresholdDays = "crunchThresholdDays"
        static let dueThisWeekPriorityBoost = "dueThisWeekPriorityBoost"
        // Calendar view settings
        static let calendarDetailMode = "calendarDetailMode"
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

    // MARK: - Deadline-Aware Scheduling

    /// Minimum number of distinct projects to schedule per day (flexible, default: 2)
    var minProjectsPerDay: Int {
        didSet { defaults.set(minProjectsPerDay, forKey: Keys.minProjectsPerDay) }
    }

    /// Maximum number of distinct projects to schedule per day (hard limit, default: 3)
    var maxProjectsPerDay: Int {
        didSet { defaults.set(maxProjectsPerDay, forKey: Keys.maxProjectsPerDay) }
    }

    /// Days before deadline to enter "crunch mode" where all time goes to that project (default: 2)
    var crunchThresholdDays: Int {
        didSet { defaults.set(crunchThresholdDays, forKey: Keys.crunchThresholdDays) }
    }

    /// Whether to give priority boost to items due within the week (default: true)
    var dueThisWeekPriorityBoost: Bool {
        didSet { defaults.set(dueThisWeekPriorityBoost, forKey: Keys.dueThisWeekPriorityBoost) }
    }

    // MARK: - Calendar View

    /// Whether to show detailed calendar view with events inline (default: false for simplified mode)
    var calendarDetailMode: Bool {
        didSet { defaults.set(calendarDetailMode, forKey: Keys.calendarDetailMode) }
    }

    // MARK: - Language

    /// App language setting (default: follow system)
    var languageOption: LanguageOption {
        didSet {
            defaults.set(languageOption.rawValue, forKey: Keys.appLanguage)
            applyLanguage()
        }
    }

    /// Apply the selected language to the app
    private func applyLanguage() {
        if let localeId = languageOption.localeIdentifier {
            UserDefaults.standard.set([localeId], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }

    // MARK: - Appearance Mode

    /// Selected appearance mode (default: system)
    var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    /// Computed color scheme for SwiftUI
    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
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
        // Deadline-aware scheduling settings
        self.minProjectsPerDay = defaults.object(forKey: Keys.minProjectsPerDay) as? Int ?? 2
        self.maxProjectsPerDay = defaults.object(forKey: Keys.maxProjectsPerDay) as? Int ?? 3
        self.crunchThresholdDays = defaults.object(forKey: Keys.crunchThresholdDays) as? Int ?? 2
        self.dueThisWeekPriorityBoost = defaults.object(forKey: Keys.dueThisWeekPriorityBoost) as? Bool ?? true
        // Calendar view settings
        self.calendarDetailMode = defaults.object(forKey: Keys.calendarDetailMode) as? Bool ?? false

        // Load language option
        if let langString = defaults.string(forKey: Keys.appLanguage),
           let lang = LanguageOption(rawValue: langString) {
            self.languageOption = lang
        } else {
            self.languageOption = .system
        }

        // Load appearance mode
        if let modeString = defaults.string(forKey: Keys.appearanceMode),
           let mode = AppearanceMode(rawValue: modeString) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .dark
        }

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
