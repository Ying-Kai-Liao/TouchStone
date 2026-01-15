import Foundation
import SwiftUI

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
        static let defaultSessionMinutes = "defaultSessionMinutes"
        static let lunchEnabled = "lunchEnabled"
        static let lunchStartHour = "lunchStartHour"
        static let lunchEndHour = "lunchEndHour"
        static let dinnerEnabled = "dinnerEnabled"
        static let dinnerStartHour = "dinnerStartHour"
        static let dinnerEndHour = "dinnerEndHour"
        static let restBetweenSessionsEnabled = "restBetweenSessionsEnabled"
        static let workIntervalMinutes = "workIntervalMinutes"
        static let restDurationMinutes = "restDurationMinutes"
        static let appLanguage = "appLanguage"
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

    /// Default session length in minutes (default: 60)
    var defaultSessionMinutes: Int {
        didSet { defaults.set(defaultSessionMinutes, forKey: Keys.defaultSessionMinutes) }
    }

    // MARK: - Daily Rules (Blocked Slots)

    /// Whether lunch break is enabled
    var lunchEnabled: Bool {
        didSet { defaults.set(lunchEnabled, forKey: Keys.lunchEnabled) }
    }

    /// Hour when lunch starts (default: 12 PM)
    var lunchStartHour: Int {
        didSet { defaults.set(lunchStartHour, forKey: Keys.lunchStartHour) }
    }

    /// Hour when lunch ends (default: 1 PM)
    var lunchEndHour: Int {
        didSet { defaults.set(lunchEndHour, forKey: Keys.lunchEndHour) }
    }

    /// Whether dinner break is enabled
    var dinnerEnabled: Bool {
        didSet { defaults.set(dinnerEnabled, forKey: Keys.dinnerEnabled) }
    }

    /// Hour when dinner starts (default: 6 PM)
    var dinnerStartHour: Int {
        didSet { defaults.set(dinnerStartHour, forKey: Keys.dinnerStartHour) }
    }

    /// Hour when dinner ends (default: 7 PM)
    var dinnerEndHour: Int {
        didSet { defaults.set(dinnerEndHour, forKey: Keys.dinnerEndHour) }
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

    // MARK: - Language (Future)

    /// App language setting (default: follow system)
    var appLanguage: String {
        didSet { defaults.set(appLanguage, forKey: Keys.appLanguage) }
    }

    // MARK: - Initialization

    init() {
        // Load from UserDefaults with defaults
        self.dailyProductiveHours = defaults.object(forKey: Keys.dailyProductiveHours) as? Int ?? 6
        self.workDayStartHour = defaults.object(forKey: Keys.workDayStartHour) as? Int ?? 9
        self.workDayEndHour = defaults.object(forKey: Keys.workDayEndHour) as? Int ?? 21
        self.defaultSessionMinutes = defaults.object(forKey: Keys.defaultSessionMinutes) as? Int ?? 60
        self.lunchEnabled = defaults.object(forKey: Keys.lunchEnabled) as? Bool ?? true
        self.lunchStartHour = defaults.object(forKey: Keys.lunchStartHour) as? Int ?? 12
        self.lunchEndHour = defaults.object(forKey: Keys.lunchEndHour) as? Int ?? 13
        self.dinnerEnabled = defaults.object(forKey: Keys.dinnerEnabled) as? Bool ?? true
        self.dinnerStartHour = defaults.object(forKey: Keys.dinnerStartHour) as? Int ?? 18
        self.dinnerEndHour = defaults.object(forKey: Keys.dinnerEndHour) as? Int ?? 19
        self.restBetweenSessionsEnabled = defaults.object(forKey: Keys.restBetweenSessionsEnabled) as? Bool ?? true
        self.workIntervalMinutes = defaults.object(forKey: Keys.workIntervalMinutes) as? Int ?? 60
        self.restDurationMinutes = defaults.object(forKey: Keys.restDurationMinutes) as? Int ?? 15
        self.appLanguage = defaults.string(forKey: Keys.appLanguage) ?? "system"
    }

    // MARK: - Convenience Methods

    /// Get blocked time slots for a given date (lunch/dinner)
    func blockedSlots(for date: Date) -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        var slots: [(start: Date, end: Date)] = []

        if lunchEnabled {
            if let start = calendar.date(bySettingHour: lunchStartHour, minute: 0, second: 0, of: date),
               let end = calendar.date(bySettingHour: lunchEndHour, minute: 0, second: 0, of: date) {
                slots.append((start, end))
            }
        }

        if dinnerEnabled {
            if let start = calendar.date(bySettingHour: dinnerStartHour, minute: 0, second: 0, of: date),
               let end = calendar.date(bySettingHour: dinnerEndHour, minute: 0, second: 0, of: date) {
                slots.append((start, end))
            }
        }

        return slots
    }

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
