import SwiftUI
import SwiftData

struct StoneEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let stone: StoneEvent
    let onSave: () -> Void

    @State private var title: String
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int
    @State private var recurrenceType: RecurrenceType
    @State private var specificDate: Date
    @State private var customDays: Set<Int>

    private let hours = Array(0...23)
    private let minutes = [0, 15, 30, 45]

    init(stone: StoneEvent, onSave: @escaping () -> Void) {
        self.stone = stone
        self.onSave = onSave

        // Initialize state from existing stone
        _title = State(initialValue: stone.title)
        _startHour = State(initialValue: stone.startHour)
        _startMinute = State(initialValue: stone.startMinute)
        _endHour = State(initialValue: stone.endHour)
        _endMinute = State(initialValue: stone.endMinute)
        _recurrenceType = State(initialValue: stone.recurrence.type)
        _specificDate = State(initialValue: stone.specificDate ?? Date())
        _customDays = State(initialValue: Set(stone.recurrence.customDays ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Event name", text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Time") {
                    HStack {
                        Text("Start")
                        Spacer()
                        Picker("Hour", selection: $startHour) {
                            ForEach(hours, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(":")

                        Picker("Minute", selection: $startMinute) {
                            ForEach(minutes, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("End")
                        Spacer()
                        Picker("Hour", selection: $endHour) {
                            ForEach(hours, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(":")

                        Picker("Minute", selection: $endMinute) {
                            ForEach(minutes, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Repeats") {
                    Picker("Recurrence", selection: $recurrenceType) {
                        Text("One time").tag(RecurrenceType.none)
                        Text("Daily").tag(RecurrenceType.daily)
                        Text("Weekdays").tag(RecurrenceType.weekdays)
                        Text("Weekends").tag(RecurrenceType.weekends)
                        Text("Weekly").tag(RecurrenceType.weekly)
                        Text("Custom days").tag(RecurrenceType.custom)
                    }

                    if recurrenceType == .none || recurrenceType == .weekly {
                        DatePicker("Date", selection: $specificDate, displayedComponents: .date)
                    }

                    if recurrenceType == .custom {
                        customDaysSelector
                    }
                }
            }
            .navigationTitle("Edit Stone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty || !isValidTimeRange)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var customDaysSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select days")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach([(1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")], id: \.0) { day, label in
                    Button {
                        if customDays.contains(day) {
                            customDays.remove(day)
                        } else {
                            customDays.insert(day)
                        }
                    } label: {
                        Text(label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(width: 32, height: 32)
                            .background(customDays.contains(day) ? UserPreferences.shared.accentColor : Color(.tertiarySystemFill))
                            .foregroundStyle(customDays.contains(day) ? .white : .primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var isValidTimeRange: Bool {
        let startTotal = startHour * 60 + startMinute
        let endTotal = endHour * 60 + endMinute
        return endTotal > startTotal
    }

    private func formatHour(_ hour: Int) -> String {
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let period = hour >= 12 ? "PM" : "AM"
        return "\(displayHour) \(period)"
    }

    private func saveChanges() {
        // Update the existing stone
        stone.title = title
        stone.startHour = startHour
        stone.startMinute = startMinute
        stone.endHour = endHour
        stone.endMinute = endMinute

        // Update recurrence
        let recurrence: RecurrencePattern
        switch recurrenceType {
        case .none: recurrence = .none
        case .daily: recurrence = .daily
        case .weekdays: recurrence = .weekdays
        case .weekends: recurrence = .weekends
        case .weekly: recurrence = .weekly
        case .custom: recurrence = .custom(days: Array(customDays))
        }
        stone.recurrence = recurrence

        // Update specific date
        stone.specificDate = (recurrenceType == .none || recurrenceType == .weekly) ? specificDate : nil

        onSave()
        dismiss()
    }
}

#Preview {
    let stone = StoneEvent(
        title: "Morning Meeting",
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 30
    )

    return StoneEditSheet(stone: stone, onSave: {})
}
