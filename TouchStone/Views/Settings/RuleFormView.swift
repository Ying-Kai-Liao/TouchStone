import SwiftUI
import SwiftData

// MARK: - Rule Form View

/// Form for creating or editing a rule.
struct RuleFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let rule: Rule?

    @State private var title: String = ""
    @State private var startHour: Int = 12
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 13
    @State private var endMinute: Int = 0
    @State private var recurrenceType: RecurrenceType = .daily
    @State private var customDays: Set<Int> = []

    private var isEditing: Bool { rule != nil }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
            } header: {
                Text("Name")
            }

            Section {
                HStack {
                    Text("Start")
                    Spacer()
                    Picker("Hour", selection: $startHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    Text(":")
                        .foregroundStyle(.secondary)

                    Picker("Minute", selection: $startMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("End")
                    Spacer()
                    Picker("Hour", selection: $endHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    Text(":")
                        .foregroundStyle(.secondary)

                    Picker("Minute", selection: $endMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            } header: {
                Text("Time")
            }

            Section {
                Picker("Repeats", selection: $recurrenceType) {
                    Text("Daily").tag(RecurrenceType.daily)
                    Text("Weekdays").tag(RecurrenceType.weekdays)
                    Text("Weekends").tag(RecurrenceType.weekends)
                    Text("Custom").tag(RecurrenceType.custom)
                }

                if recurrenceType == .custom {
                    DaySelector(selectedDays: $customDays)
                }
            } header: {
                Text("Recurrence")
            }
        }
        .navigationTitle(isEditing ? "Edit Rule" : "New Rule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add") {
                    saveRule()
                    dismiss()
                }
                .disabled(title.isEmpty)
            }
        }
        .onAppear {
            if let rule = rule {
                loadRule(rule)
            }
        }
    }

    // MARK: - Helper Functions

    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour) \(period)"
    }

    private func loadRule(_ rule: Rule) {
        title = rule.title
        startHour = rule.startHour
        startMinute = rule.startMinute
        endHour = rule.endHour
        endMinute = rule.endMinute
        recurrenceType = rule.recurrence.type

        if let days = rule.recurrence.customDays {
            customDays = Set(days)
        }
    }

    private func saveRule() {
        let recurrence: RecurrencePattern
        if recurrenceType == .custom {
            recurrence = .custom(days: Array(customDays).sorted())
        } else {
            recurrence = RecurrencePattern(type: recurrenceType)
        }

        if let rule = rule {
            // Update existing rule
            rule.title = title
            rule.startHour = startHour
            rule.startMinute = startMinute
            rule.endHour = endHour
            rule.endMinute = endMinute
            rule.recurrence = recurrence
        } else {
            // Create new rule
            let newRule = Rule(
                title: title,
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute,
                recurrence: recurrence
            )
            modelContext.insert(newRule)
        }
    }
}

// MARK: - Day Selector

/// Multi-select for days of the week.
struct DaySelector: View {
    @Binding var selectedDays: Set<Int>

    private let days = [
        (1, "Sun"),
        (2, "Mon"),
        (3, "Tue"),
        (4, "Wed"),
        (5, "Thu"),
        (6, "Fri"),
        (7, "Sat")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.0) { day, name in
                DayButton(
                    name: name,
                    isSelected: selectedDays.contains(day)
                ) {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DayButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 36, height: 36)
                .background(isSelected ? UserPreferences.shared.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RuleFormView(rule: nil)
    }
    .modelContainer(for: Rule.self, inMemory: true)
}
