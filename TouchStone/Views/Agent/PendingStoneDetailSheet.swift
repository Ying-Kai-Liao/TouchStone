import SwiftUI

/// Detail sheet for editing a pending stone event before confirmation
struct PendingStoneDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let stone: AgentService.PendingStone
    let onSave: (AgentService.PendingStone) -> Void
    let onDelete: () -> Void

    // Editable state
    @State private var title: String
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int
    @State private var date: Date?
    @State private var isRecurring: Bool
    @State private var recurrenceType: RecurrenceOption
    @State private var customDays: Set<Int>

    @State private var showDeleteConfirmation = false

    enum RecurrenceOption: String, CaseIterable {
        case none = "None"
        case daily = "Daily"
        case weekdays = "Weekdays"
        case weekends = "Weekends"
        case weekly = "Weekly"
        case custom = "Custom"
    }

    init(stone: AgentService.PendingStone, onSave: @escaping (AgentService.PendingStone) -> Void, onDelete: @escaping () -> Void) {
        self.stone = stone
        self.onSave = onSave
        self.onDelete = onDelete

        // Initialize state from stone
        _title = State(initialValue: stone.title)
        _startHour = State(initialValue: stone.startHour)
        _startMinute = State(initialValue: stone.startMinute)
        _endHour = State(initialValue: stone.endHour)
        _endMinute = State(initialValue: stone.endMinute)

        // Parse date
        if let dateStr = stone.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _date = State(initialValue: formatter.date(from: dateStr))
        } else {
            _date = State(initialValue: nil)
        }

        _isRecurring = State(initialValue: stone.isRecurring)

        // Parse recurrence type
        if let recType = stone.recurrenceType?.lowercased() {
            switch recType {
            case "daily": _recurrenceType = State(initialValue: .daily)
            case "weekdays": _recurrenceType = State(initialValue: .weekdays)
            case "weekends": _recurrenceType = State(initialValue: .weekends)
            case "weekly": _recurrenceType = State(initialValue: .weekly)
            case "custom": _recurrenceType = State(initialValue: .custom)
            default: _recurrenceType = State(initialValue: .none)
            }
        } else {
            _recurrenceType = State(initialValue: .none)
        }

        // Parse custom days
        _customDays = State(initialValue: Set(stone.customDays ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title section
                Section("Event Details") {
                    TextField("Title", text: $title)
                }

                // Time section
                Section("Time") {
                    timePicker(label: "Start", hour: $startHour, minute: $startMinute)
                    timePicker(label: "End", hour: $endHour, minute: $endMinute)
                }

                // Date/Recurrence section
                Section("Schedule") {
                    Toggle("Recurring", isOn: $isRecurring)

                    if isRecurring {
                        Picker("Repeat", selection: $recurrenceType) {
                            ForEach(RecurrenceOption.allCases.filter { $0 != .none }, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }

                        if recurrenceType == .custom {
                            customDaysPicker
                        }
                    } else {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { date ?? Date() },
                                set: { date = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                // Delete section
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Event")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Event")
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
                    .disabled(title.isEmpty)
                }
            }
            .confirmationDialog("Delete Event?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the event from pending actions.")
            }
        }
    }

    // MARK: - Time Picker

    private func timePicker(label: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack {
            Text(label)

            Spacer()

            Picker("Hour", selection: hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text("\(h)").tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 50, height: 100)
            .clipped()

            Text(":")

            Picker("Minute", selection: minute) {
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 50, height: 100)
            .clipped()
        }
    }

    // MARK: - Custom Days Picker

    private var customDaysPicker: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Select Days")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach([(0, "S"), (1, "M"), (2, "T"), (3, "W"), (4, "T"), (5, "F"), (6, "S")], id: \.0) { day, label in
                    Button {
                        if customDays.contains(day) {
                            customDays.remove(day)
                        } else {
                            customDays.insert(day)
                        }
                    } label: {
                        Text(label)
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(customDays.contains(day) ? .bold : .regular)
                            .foregroundStyle(customDays.contains(day) ? .white : DesignSystem.Colors.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(customDays.contains(day) ? DesignSystem.Colors.accent : DesignSystem.Colors.cardBackground)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Save

    private func saveChanges() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let dateString: String?
        if isRecurring {
            dateString = nil
        } else {
            dateString = date.map { formatter.string(from: $0) }
        }

        let recTypeString: String?
        if isRecurring {
            recTypeString = recurrenceType.rawValue.lowercased()
        } else {
            recTypeString = nil
        }

        let customDaysArray: [Int]?
        if isRecurring && recurrenceType == .custom {
            customDaysArray = Array(customDays).sorted()
        } else {
            customDaysArray = nil
        }

        let updatedStone = AgentService.PendingStone(
            tempId: stone.tempId,
            title: title,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            date: dateString,
            isRecurring: isRecurring,
            recurrenceType: recTypeString,
            customDays: customDaysArray
        )

        onSave(updatedStone)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    PendingStoneDetailSheet(
        stone: AgentService.PendingStone(
            tempId: "preview-1",
            title: "Team Standup",
            startHour: 10,
            startMinute: 0,
            endHour: 10,
            endMinute: 30,
            date: "2024-01-22",
            isRecurring: false,
            recurrenceType: nil,
            customDays: nil
        ),
        onSave: { _ in },
        onDelete: {}
    )
}
