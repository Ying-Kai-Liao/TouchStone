import SwiftUI
import SwiftData

// MARK: - Context Form View

/// Form for creating or editing a day context.
struct ContextFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let context: DayContext?

    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var contextType: DayContextType = .custom
    @State private var workMode: DayContextWorkMode = .normal
    @State private var capacityPercent: Int = 50
    @State private var fixedTaskDescription: String = ""
    @State private var notes: String = ""
    @State private var showSaveError = false

    private var isEditing: Bool { context != nil }

    private var isValid: Bool {
        !name.isEmpty && endDate >= startDate
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    nameSection
                    dateSection
                    typeSection
                    workModeSection
                    notesSection
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle(isEditing ? "Edit Context" : "New Context")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add") {
                    saveContext()
                    dismiss()
                }
                .disabled(!isValid)
                .foregroundStyle(isValid ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
            }
        }
        .onAppear {
            if let context = context {
                loadContext(context)
            }
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unable to save the context. Please try again.")
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("NAME")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            TextField("e.g., Christmas Break, Team Offsite", text: $name)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                        .fill(DesignSystem.Colors.cardBackground)
                )
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("DATES")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            VStack(spacing: 0) {
                HStack {
                    Text("Start")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(DesignSystem.Colors.accent)
                }
                .padding(DesignSystem.Spacing.lg)

                Divider()
                    .background(DesignSystem.Colors.divider)

                HStack {
                    Text("End")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden()
                        .tint(DesignSystem.Colors.accent)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            // Duration indicator
            if endDate >= startDate {
                let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                Text("\(days + 1) day\(days == 0 ? "" : "s")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.leading, DesignSystem.Spacing.sm)
            }
        }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("TYPE")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                ForEach(DayContextType.allCases) { type in
                    Button {
                        contextType = type
                    } label: {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: type.icon)
                                .font(.system(size: 20))
                            Text(type.displayName)
                                .font(DesignSystem.Typography.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                                .fill(contextType == type ? DesignSystem.Colors.accent.opacity(0.2) : DesignSystem.Colors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                                .strokeBorder(contextType == type ? DesignSystem.Colors.accent : Color.clear, lineWidth: 2)
                        )
                        .foregroundStyle(contextType == type ? DesignSystem.Colors.accent : DesignSystem.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Work Mode Section

    private var workModeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("WORK MODE")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            VStack(spacing: 0) {
                ForEach(DayContextWorkMode.allCases) { mode in
                    Button {
                        workMode = mode
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(workMode == mode ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.displayName)
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                                Text(mode.description)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }

                            Spacer()

                            if workMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(DesignSystem.Colors.accent)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                    .buttonStyle(.plain)

                    if mode != DayContextWorkMode.allCases.last {
                        Divider()
                            .background(DesignSystem.Colors.divider)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            // Conditional fields based on work mode
            if workMode == .reduced {
                capacitySlider
            } else if workMode == .fixed {
                fixedTaskField
            }
        }
    }

    // MARK: - Capacity Slider (for reduced mode)

    private var capacitySlider: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Capacity")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Text("\(capacityPercent)%")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            Slider(
                value: Binding(
                    get: { Double(capacityPercent) },
                    set: { capacityPercent = Int($0) }
                ),
                in: 10...90,
                step: 10
            )
            .tint(DesignSystem.Colors.accent)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Fixed Task Field (for fixed mode)

    private var fixedTaskField: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("FIXED TASK")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            TextField("What should you focus on?", text: $fixedTaskDescription)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                        .fill(DesignSystem.Colors.cardBackground)
                )
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("NOTES (OPTIONAL)")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            TextField("Any additional notes...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                        .fill(DesignSystem.Colors.cardBackground)
                )
        }
    }

    // MARK: - Helper Functions

    private func loadContext(_ context: DayContext) {
        name = context.name
        startDate = context.startDate
        endDate = context.endDate
        contextType = context.type
        workMode = context.workMode
        capacityPercent = context.capacityPercent
        fixedTaskDescription = context.fixedTaskDescription ?? ""
        notes = context.notes ?? ""
    }

    private func saveContext() {
        do {
            if let context = context {
                // Update existing context
                context.name = name
                context.startDate = Calendar.current.startOfDay(for: startDate)
                context.endDate = Calendar.current.startOfDay(for: endDate)
                context.type = contextType
                context.workMode = workMode
                context.capacityPercent = capacityPercent
                context.fixedTaskDescription = workMode == .fixed ? fixedTaskDescription : nil
                context.notes = notes.isEmpty ? nil : notes
            } else {
                // Create new context
                let newContext = DayContext(
                    name: name,
                    startDate: startDate,
                    endDate: endDate,
                    type: contextType,
                    workMode: workMode,
                    capacityPercent: capacityPercent,
                    fixedTaskDescription: workMode == .fixed ? fixedTaskDescription : nil,
                    notes: notes.isEmpty ? nil : notes
                )
                modelContext.insert(newContext)
            }
            try modelContext.save()
        } catch {
            showSaveError = true
        }
    }
}

#Preview {
    NavigationStack {
        ContextFormView(context: nil)
    }
    .modelContainer(for: DayContext.self, inMemory: true)
}
