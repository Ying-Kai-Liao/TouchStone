import SwiftUI

/// Detail sheet for editing a pending day context before confirmation
struct PendingContextDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let context: AgentService.PendingDayContext
    let onSave: (AgentService.PendingDayContext) -> Void
    let onDelete: () -> Void

    // Editable state
    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var type: DayContextType
    @State private var workMode: DayContextWorkMode
    @State private var capacityPercent: Int
    @State private var fixedTaskDescription: String

    @State private var showDeleteConfirmation = false

    init(context: AgentService.PendingDayContext, onSave: @escaping (AgentService.PendingDayContext) -> Void, onDelete: @escaping () -> Void) {
        self.context = context
        self.onSave = onSave
        self.onDelete = onDelete

        // Initialize state from context
        _name = State(initialValue: context.name)
        _capacityPercent = State(initialValue: context.capacityPercent)
        _fixedTaskDescription = State(initialValue: context.fixedTaskDescription ?? "")

        // Parse dates
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        _startDate = State(initialValue: formatter.date(from: context.startDate) ?? Date())
        _endDate = State(initialValue: formatter.date(from: context.endDate) ?? Date())

        // Parse type
        _type = State(initialValue: DayContextType(rawValue: context.type) ?? .custom)

        // Parse work mode
        _workMode = State(initialValue: DayContextWorkMode(rawValue: context.workMode) ?? .normal)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Context details
                Section("Context Details") {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $type) {
                        ForEach(DayContextType.allCases, id: \.self) { contextType in
                            Text(contextType.displayName).tag(contextType)
                        }
                    }
                }

                // Dates section
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }

                // Work mode section
                Section("Work Mode") {
                    Picker("Mode", selection: $workMode) {
                        ForEach(DayContextWorkMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    if workMode == .reduced {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Capacity: \(capacityPercent)%")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                            Slider(value: Binding(
                                get: { Double(capacityPercent) },
                                set: { capacityPercent = Int($0) }
                            ), in: 0...100, step: 10)
                        }
                    }

                    if workMode == .fixed {
                        TextField("Task Description", text: $fixedTaskDescription, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }

                // Delete section
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Context")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Context")
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
                    .disabled(name.isEmpty || startDate > endDate)
                }
            }
            .confirmationDialog("Delete Context?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the context from pending actions.")
            }
        }
    }

    // MARK: - Save

    private func saveChanges() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let updatedContext = AgentService.PendingDayContext(
            tempId: context.tempId,
            name: name,
            startDate: formatter.string(from: startDate),
            endDate: formatter.string(from: endDate),
            type: type.rawValue,
            workMode: workMode.rawValue,
            capacityPercent: capacityPercent,
            fixedTaskDescription: workMode == .fixed ? fixedTaskDescription : nil
        )

        onSave(updatedContext)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    PendingContextDetailSheet(
        context: AgentService.PendingDayContext(
            tempId: "preview-1",
            name: "Summer Vacation",
            startDate: "2024-07-01",
            endDate: "2024-07-14",
            type: "vacation",
            workMode: "none",
            capacityPercent: 0,
            fixedTaskDescription: nil
        ),
        onSave: { _ in },
        onDelete: {}
    )
}
