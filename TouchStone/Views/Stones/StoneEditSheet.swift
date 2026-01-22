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
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        // Name section
                        nameSection

                        // Time section
                        timeSection

                        // Recurrence section
                        recurrenceSection
                    }
                    .padding(DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Edit Stone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty || !isValidTimeRange)
                    .foregroundStyle(title.isEmpty || !isValidTimeRange ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("NAME")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            TextField("Event name", text: $title)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .textInputAutocapitalization(.sentences)
                .padding(DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                        .fill(DesignSystem.Colors.cardBackground)
                )
        }
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("TIME")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            VStack(spacing: 0) {
                // Start time
                HStack {
                    Text("Start")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Picker("Hour", selection: $startHour) {
                        ForEach(hours, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(DesignSystem.Colors.accent)

                    Text(":")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Picker("Minute", selection: $startMinute) {
                        ForEach(minutes, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(DesignSystem.Colors.accent)
                }
                .padding(DesignSystem.Spacing.lg)

                Divider()
                    .background(DesignSystem.Colors.divider)

                // End time
                HStack {
                    Text("End")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Picker("Hour", selection: $endHour) {
                        ForEach(hours, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(DesignSystem.Colors.accent)

                    Text(":")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Picker("Minute", selection: $endMinute) {
                        ForEach(minutes, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(DesignSystem.Colors.accent)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    // MARK: - Recurrence Section

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("REPEATS")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            VStack(spacing: 0) {
                // Recurrence type picker
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    recurrenceOptionRow("One time", type: .none)
                    recurrenceOptionRow("Daily", type: .daily)
                    recurrenceOptionRow("Weekdays", type: .weekdays)
                    recurrenceOptionRow("Weekends", type: .weekends)
                    recurrenceOptionRow("Weekly", type: .weekly)
                    recurrenceOptionRow("Custom days", type: .custom)
                }
                .padding(DesignSystem.Spacing.lg)

                // Date picker for one-time or weekly
                if recurrenceType == .none || recurrenceType == .weekly {
                    Divider()
                        .background(DesignSystem.Colors.divider)

                    HStack {
                        Text("Date")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                        DatePicker("", selection: $specificDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(DesignSystem.Colors.accent)
                    }
                    .padding(DesignSystem.Spacing.lg)
                }

                // Custom days selector
                if recurrenceType == .custom {
                    Divider()
                        .background(DesignSystem.Colors.divider)

                    customDaysSelector
                        .padding(DesignSystem.Spacing.lg)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    private func recurrenceOptionRow(_ label: String, type: RecurrenceType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                recurrenceType = type
            }
        } label: {
            HStack {
                Text(label)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                if recurrenceType == type {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var customDaysSelector: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Select days")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

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
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .frame(width: 36, height: 36)
                            .background(customDays.contains(day) ? DesignSystem.Colors.accent : DesignSystem.Colors.backgroundLight)
                            .foregroundStyle(customDays.contains(day) ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
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
