import SwiftUI

// MARK: - Chart Slice Data

/// Represents a slice in the time allocation pie chart.
/// Used by PieChartView to render the donut chart visualization.
struct ChartSlice: Identifiable {
    let id = UUID()
    let label: String
    let hours: Double
    let color: Color
    let isProject: Bool
}

// MARK: - Day Detail State

/// View model to manage the computed state for DayDetailView.
/// Holds the day's data and computed chart information.
///
/// This class centralizes the business logic for:
/// - Date and day state management
/// - Time allocation toggle state
/// - Chart data computation
@Observable
final class DayDetailState {
    // MARK: - Properties

    let date: Date
    private(set) var dayState: DayState?

    // UI State
    var showTimeAllocation: Bool = false

    // Dependencies
    private let calendar = Calendar.current
    private var prefs: UserPreferences { UserPreferences.shared }

    // MARK: - Initialization

    init(date: Date) {
        self.date = date
    }

    // MARK: - Computed Properties

    /// Whether the date is today
    var isToday: Bool {
        calendar.isDateInToday(date)
    }

    /// Whether the date is tomorrow
    var isTomorrow: Bool {
        calendar.isDateInTomorrow(date)
    }

    /// Formatted date string (e.g., "Friday, January 24")
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    /// Suggested sessions for this day from the computed day state
    var suggestedSessions: [SuggestedSession] {
        dayState?.suggestedSessions ?? []
    }

    // MARK: - Day State Computation

    /// Compute the day state with the provided data.
    func computeDayState(
        stones: [StoneEvent],
        projects: [Project],
        contexts: [DayContext]
    ) {
        let state = DayState(date: date)
        state.compute(
            stones: stones,
            projects: projects,
            contexts: contexts
        )
        dayState = state
    }
}
