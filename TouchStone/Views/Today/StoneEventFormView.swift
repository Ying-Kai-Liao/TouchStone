import SwiftUI
import SwiftData

struct StoneEventFormView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (StoneEvent) -> Void

    @State private var title: String = ""
    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 10
    @State private var endMinute: Int = 0
    @State private var recurrenceType: RecurrenceType = .none
    @State private var specificDate: Date = Date()
    @State private var customDays: Set<Int> = []

    private let hours = Array(0...23)
    private let minutes = [0, 15, 30, 45]

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
            .navigationTitle("Add Stone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveStone()
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
                            .background(customDays.contains(day) ? Color.blue : Color(.tertiarySystemFill))
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

    private func saveStone() {
        let recurrence: RecurrencePattern
        switch recurrenceType {
        case .none: recurrence = .none
        case .daily: recurrence = .daily
        case .weekdays: recurrence = .weekdays
        case .weekends: recurrence = .weekends
        case .weekly: recurrence = .weekly
        case .custom: recurrence = .custom(days: Array(customDays))
        }

        let stone = StoneEvent(
            title: title,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            specificDate: (recurrenceType == .none || recurrenceType == .weekly) ? specificDate : nil,
            recurrence: recurrence
        )

        onSave(stone)
        dismiss()
    }
}

#Preview {
    StoneEventFormView { _ in }
}
