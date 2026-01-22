import SwiftUI
import EventKit

struct ImportEventsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var importService = CalendarImportService()

    let onImport: ([StoneEvent]) -> Void

    @State private var selectedCalendars: Set<String> = []
    @State private var importableEvents: [ImportableEvent] = []
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var showingDateRange = false

    var body: some View {
        NavigationStack {
            Group {
                switch importService.authorizationStatus {
                case .notDetermined:
                    requestAccessView
                case .denied, .restricted:
                    accessDeniedView
                case .fullAccess, .writeOnly:
                    eventSelectionView
                @unknown default:
                    requestAccessView
                }
            }
            .navigationTitle("Import Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if importService.authorizationStatus == .fullAccess {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            importSelectedEvents()
                        }
                        .disabled(selectedEvents.isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Request Access View

    private var requestAccessView: some View {
        ContentUnavailableView {
            Label("Calendar Access", systemImage: "calendar")
        } description: {
            Text("TouchStone needs access to your calendar to import events as stones.")
        } actions: {
            Button("Grant Access") {
                Task {
                    let granted = await importService.requestAccess()
                    if granted {
                        loadCalendarsAndEvents()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Access Denied View

    private var accessDeniedView: some View {
        ContentUnavailableView {
            Label("Access Denied", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Calendar access was denied. Please enable it in Settings to import events.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Event Selection View

    private var eventSelectionView: some View {
        List {
            Section {
                DisclosureGroup("Date Range", isExpanded: $showingDateRange) {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)

                    Button("Refresh Events") {
                        fetchEvents()
                    }
                }
            }

            if !importService.calendars.isEmpty {
                Section("Calendars") {
                    ForEach(importService.calendars, id: \.calendarIdentifier) { calendar in
                        CalendarRow(
                            calendar: calendar,
                            isSelected: selectedCalendars.contains(calendar.calendarIdentifier)
                        ) {
                            toggleCalendar(calendar)
                        }
                    }
                }
            }

            if importableEvents.isEmpty {
                Section {
                    if importService.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ContentUnavailableView {
                            Label("No Events", systemImage: "calendar.badge.minus")
                        } description: {
                            Text("No events found in the selected date range.")
                        }
                    }
                }
            } else {
                Section("Events (\(selectedEvents.count) selected)") {
                    selectAllButton

                    ForEach($importableEvents) { $event in
                        if !event.isAllDay {
                            ImportEventRow(event: $event)
                        }
                    }
                }

                if hasAllDayEvents {
                    Section {
                        Text("All-day events are not shown as they cannot be imported as stones.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            loadCalendarsAndEvents()
        }
    }

    private var selectAllButton: some View {
        Button {
            toggleSelectAll()
        } label: {
            HStack {
                Image(systemName: allNonAllDaySelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(allNonAllDaySelected ? .blue : .secondary)
                Text(allNonAllDaySelected ? "Deselect All" : "Select All")
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Computed Properties

    private var selectedEvents: [ImportableEvent] {
        importableEvents.filter { $0.isSelected }
    }

    private var hasAllDayEvents: Bool {
        importableEvents.contains { $0.isAllDay }
    }

    private var allNonAllDaySelected: Bool {
        let nonAllDay = importableEvents.filter { !$0.isAllDay }
        return !nonAllDay.isEmpty && nonAllDay.allSatisfy { $0.isSelected }
    }

    // MARK: - Actions

    private func loadCalendarsAndEvents() {
        importService.fetchCalendars()
        selectedCalendars = Set(importService.calendars.map { $0.calendarIdentifier })
        fetchEvents()
    }

    private func fetchEvents() {
        let calendarsToFetch = importService.calendars.filter {
            selectedCalendars.contains($0.calendarIdentifier)
        }
        importService.fetchEvents(
            from: startDate,
            to: endDate,
            calendars: calendarsToFetch.isEmpty ? nil : calendarsToFetch
        )
        importableEvents = importService.events.map { ImportableEvent(event: $0) }
    }

    private func toggleCalendar(_ calendar: EKCalendar) {
        if selectedCalendars.contains(calendar.calendarIdentifier) {
            selectedCalendars.remove(calendar.calendarIdentifier)
        } else {
            selectedCalendars.insert(calendar.calendarIdentifier)
        }
        fetchEvents()
    }

    private func toggleSelectAll() {
        let shouldSelect = !allNonAllDaySelected
        for index in importableEvents.indices {
            if !importableEvents[index].isAllDay {
                importableEvents[index].isSelected = shouldSelect
            }
        }
    }

    private func importSelectedEvents() {
        let stoneEvents = selectedEvents.map { importService.convertToStoneEvent($0.event) }
        onImport(stoneEvents)
        dismiss()
    }
}

// MARK: - Supporting Views

struct CalendarRow: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 12, height: 12)

                Text(calendar.title)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
        }
    }
}

struct ImportEventRow: View {
    @Binding var event: ImportableEvent

    var body: some View {
        Button {
            event.isSelected.toggle()
        } label: {
            HStack {
                Image(systemName: event.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(event.isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .foregroundStyle(.primary)
                        .fontWeight(.medium)

                    HStack(spacing: 8) {
                        Text(formatDateRange(event.startDate, event.endDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if event.isRecurring {
                            Label("Recurring", systemImage: "repeat")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let color = event.calendarColor {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(cgColor: color))
                                .frame(width: 8, height: 8)
                            Text(event.calendarTitle)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()
            }
        }
    }

    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let calendar = Calendar.current
        if calendar.isDate(start, inSameDayAs: end) {
            return "\(dateFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
        } else {
            return "\(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end))"
        }
    }
}

#Preview {
    ImportEventsView { _ in }
}
