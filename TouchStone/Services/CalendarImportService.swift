import Foundation
import EventKit

/// Service for importing events from the system calendar
class CalendarImportService: ObservableObject {
    private let eventStore = EKEventStore()

    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var calendars: [EKCalendar] = []
    @Published var events: [EKEvent] = []
    @Published var isLoading = false
    @Published var error: String?

    init() {
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                updateAuthorizationStatus()
            }
            return granted
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Fetch Calendars

    func fetchCalendars() {
        calendars = eventStore.calendars(for: .event)
    }

    // MARK: - Fetch Events

    func fetchEvents(from startDate: Date, to endDate: Date, calendars: [EKCalendar]? = nil) {
        isLoading = true
        error = nil

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        let fetchedEvents = eventStore.events(matching: predicate)

        // Sort by start date
        events = fetchedEvents.sorted { $0.startDate < $1.startDate }
        isLoading = false
    }

    // MARK: - Convert to StoneEvent

    func convertToStoneEvent(_ ekEvent: EKEvent) -> StoneEvent {
        let calendar = Calendar.current

        let startHour = calendar.component(.hour, from: ekEvent.startDate)
        let startMinute = calendar.component(.minute, from: ekEvent.startDate)
        let endHour = calendar.component(.hour, from: ekEvent.endDate)
        let endMinute = calendar.component(.minute, from: ekEvent.endDate)

        // Determine recurrence pattern
        let recurrence: RecurrencePattern
        let specificDate: Date?

        if let recurrenceRules = ekEvent.recurrenceRules, let rule = recurrenceRules.first {
            recurrence = convertRecurrenceRule(rule)
            specificDate = ekEvent.startDate
        } else {
            recurrence = .none
            specificDate = ekEvent.startDate
        }

        return StoneEvent(
            title: ekEvent.title ?? "Untitled Event",
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            specificDate: specificDate,
            recurrence: recurrence
        )
    }

    private func convertRecurrenceRule(_ rule: EKRecurrenceRule) -> RecurrencePattern {
        switch rule.frequency {
        case .daily:
            return .daily

        case .weekly:
            if let daysOfWeek = rule.daysOfTheWeek {
                let days = daysOfWeek.map { $0.dayOfTheWeek.rawValue }
                // Check for common patterns
                let weekdays = [2, 3, 4, 5, 6] // Mon-Fri
                let weekends = [1, 7] // Sun, Sat

                if Set(days) == Set(weekdays) {
                    return .weekdays
                } else if Set(days) == Set(weekends) {
                    return .weekends
                } else if days.count == 1 {
                    return .weekly
                } else {
                    return .custom(days: days)
                }
            } else {
                return .weekly
            }

        default:
            // For monthly, yearly, etc., treat as one-time
            return .none
        }
    }
}

/// Wrapper for EKEvent to make it identifiable for SwiftUI
struct ImportableEvent: Identifiable {
    let id: String
    let event: EKEvent
    var isSelected: Bool

    init(event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.event = event
        self.isSelected = false
    }

    var title: String { event.title ?? "Untitled" }
    var startDate: Date { event.startDate }
    var endDate: Date { event.endDate }
    var calendarTitle: String { event.calendar?.title ?? "Unknown" }
    var calendarColor: CGColor? { event.calendar?.cgColor }
    var isAllDay: Bool { event.isAllDay }
    var isRecurring: Bool { event.hasRecurrenceRules }
}
