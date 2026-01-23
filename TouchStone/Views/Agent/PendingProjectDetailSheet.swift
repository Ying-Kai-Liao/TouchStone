import SwiftUI

/// Detail sheet for editing a pending project before confirmation
struct PendingProjectDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let project: AgentService.PendingProject
    let onSave: (AgentService.PendingProject) -> Void
    let onDelete: () -> Void

    // Editable state
    @State private var title: String
    @State private var isPhaseMode: Bool
    @State private var archetype: String?
    @State private var deadline: Date?
    @State private var totalHours: Double
    @State private var phases: [EditablePhase]
    @State private var milestones: [EditableMilestone]

    @State private var showDeleteConfirmation = false
    @State private var editingPhaseIndex: Int?
    @State private var editingMilestoneIndex: Int?

    struct EditablePhase: Identifiable {
        let id = UUID()
        var title: String
        var phaseType: String
        var mentalRule: String
        var estimatedMinutes: Int
    }

    struct EditableMilestone: Identifiable {
        let id = UUID()
        var title: String
        var description: String?
        var sequenceOrder: Int
    }

    private let archetypes = ["lab", "hunt", "spiral", "build"]

    init(project: AgentService.PendingProject, onSave: @escaping (AgentService.PendingProject) -> Void, onDelete: @escaping () -> Void) {
        self.project = project
        self.onSave = onSave
        self.onDelete = onDelete

        _title = State(initialValue: project.title)
        _isPhaseMode = State(initialValue: project.isPhaseMode)
        _archetype = State(initialValue: project.archetype)
        _totalHours = State(initialValue: Double(project.totalPlannedMinutes) / 60.0)

        // Parse deadline
        if let deadlineStr = project.deadline {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _deadline = State(initialValue: formatter.date(from: deadlineStr))
        } else {
            _deadline = State(initialValue: nil)
        }

        // Convert phases
        _phases = State(initialValue: project.phases.map { phase in
            EditablePhase(
                title: phase.title,
                phaseType: phase.phaseType,
                mentalRule: phase.mentalRule,
                estimatedMinutes: phase.estimatedMinutes
            )
        })

        // Convert milestones
        _milestones = State(initialValue: project.milestones.enumerated().map { index, milestone in
            EditableMilestone(
                title: milestone.title,
                description: milestone.description,
                sequenceOrder: index
            )
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title section
                Section("Project Details") {
                    TextField("Title", text: $title)
                }

                // Mode section
                Section("Type") {
                    Picker("Mode", selection: $isPhaseMode) {
                        Text("Phases").tag(true)
                        Text("Milestones").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if isPhaseMode {
                        Picker("Archetype", selection: Binding(
                            get: { archetype ?? "spiral" },
                            set: { archetype = $0 }
                        )) {
                            ForEach(archetypes, id: \.self) { arch in
                                HStack {
                                    Image(systemName: archetypeIcon(for: arch))
                                    Text(arch.capitalized)
                                }
                                .tag(arch)
                            }
                        }
                    }
                }

                // Schedule section
                Section("Schedule") {
                    Toggle("Has Deadline", isOn: Binding(
                        get: { deadline != nil },
                        set: { if !$0 { deadline = nil } else { deadline = Date() } }
                    ))

                    if deadline != nil {
                        DatePicker(
                            "Deadline",
                            selection: Binding(
                                get: { deadline ?? Date() },
                                set: { deadline = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                // Time budget section (only for phase mode)
                if isPhaseMode {
                    Section("Time Budget") {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("Total Time")
                                Spacer()
                                Text(formatHours(totalHours))
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }

                            Slider(value: $totalHours, in: 1...100, step: 0.5)
                                .tint(archetypeColor)

                            // Quick time buttons
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach([5, 10, 20, 40], id: \.self) { hours in
                                    Button {
                                        withAnimation { totalHours = Double(hours) }
                                    } label: {
                                        Text("\(hours)h")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundStyle(
                                                abs(totalHours - Double(hours)) < 0.5 ? .white : DesignSystem.Colors.textSecondary
                                            )
                                            .padding(.horizontal, DesignSystem.Spacing.sm)
                                            .padding(.vertical, DesignSystem.Spacing.xs)
                                            .background(
                                                Capsule().fill(
                                                    abs(totalHours - Double(hours)) < 0.5 ? archetypeColor : DesignSystem.Colors.cardBackground
                                                )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        }
                    }
                }

                // Phases section
                if isPhaseMode {
                    Section("Phases") {
                        ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                            phaseRow(phase: phase, index: index)
                        }
                        .onDelete { indexSet in
                            phases.remove(atOffsets: indexSet)
                        }
                        .onMove { from, to in
                            phases.move(fromOffsets: from, toOffset: to)
                        }

                        Button {
                            addNewPhase()
                        } label: {
                            Label("Add Phase", systemImage: "plus.circle")
                        }
                    }
                }

                // Milestones section
                if !isPhaseMode {
                    Section("Milestones") {
                        ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                            milestoneRow(milestone: milestone, index: index)
                        }
                        .onDelete { indexSet in
                            milestones.remove(atOffsets: indexSet)
                        }
                        .onMove { from, to in
                            milestones.move(fromOffsets: from, toOffset: to)
                        }

                        Button {
                            addNewMilestone()
                        } label: {
                            Label("Add Milestone", systemImage: "plus.circle")
                        }
                    }
                }

                // Delete section
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Project")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Project")
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
            .confirmationDialog("Delete Project?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the project from pending actions.")
            }
        }
    }

    // MARK: - Phase Row

    private func phaseRow(phase: EditablePhase, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Phase \(index + 1)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Spacer()
                Text(formatMinutes(phase.estimatedMinutes))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            TextField("Title", text: Binding(
                get: { phases[index].title },
                set: { phases[index].title = $0 }
            ))
            .font(DesignSystem.Typography.body)

            TextField("Mental rule...", text: Binding(
                get: { phases[index].mentalRule },
                set: { phases[index].mentalRule = $0 }
            ))
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Milestone Row

    private func milestoneRow(milestone: EditableMilestone, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Milestone", text: Binding(
                get: { milestones[index].title },
                set: { milestones[index].title = $0 }
            ))
            .font(DesignSystem.Typography.body)

            TextField("Description (optional)", text: Binding(
                get: { milestones[index].description ?? "" },
                set: { milestones[index].description = $0.isEmpty ? nil : $0 }
            ))
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Add Items

    private func addNewPhase() {
        let phaseTypes = ["divergent", "convergent", "execution", "input", "output", "reflection"]
        let newPhase = EditablePhase(
            title: "New Phase",
            phaseType: phaseTypes[phases.count % phaseTypes.count],
            mentalRule: "Focus on this phase",
            estimatedMinutes: Int(totalHours * 60) / max(phases.count + 1, 1)
        )
        phases.append(newPhase)
    }

    private func addNewMilestone() {
        let newMilestone = EditableMilestone(
            title: "New Milestone",
            description: nil,
            sequenceOrder: milestones.count
        )
        milestones.append(newMilestone)
    }

    // MARK: - Helpers

    private var archetypeColor: Color {
        DesignSystem.Colors.archetypeColor(for: archetype)
    }

    private func archetypeIcon(for archetype: String) -> String {
        switch archetype.lowercased() {
        case "lab": return "flask"
        case "hunt": return "target"
        case "spiral": return "arrow.triangle.2.circlepath"
        case "build": return "hammer"
        default: return "folder"
        }
    }

    private func formatHours(_ hours: Double) -> String {
        let wholeHours = Int(hours)
        let minutes = Int((hours - Double(wholeHours)) * 60)
        if minutes > 0 {
            return "\(wholeHours)h \(minutes)m"
        }
        return "\(wholeHours) hours"
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
    }

    // MARK: - Save

    private func saveChanges() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let deadlineString = deadline.map { formatter.string(from: $0) }
        let totalMinutes = Int(totalHours * 60)

        // Scale phases proportionally if total time changed
        let oldTotalMinutes = project.totalPlannedMinutes
        let scaleFactor = oldTotalMinutes > 0 ? Double(totalMinutes) / Double(oldTotalMinutes) : 1.0

        let pendingPhases = phases.map { phase in
            AgentService.PendingPhase(
                title: phase.title,
                phaseType: phase.phaseType,
                mentalRule: phase.mentalRule,
                estimatedMinutes: max(30, Int(Double(phase.estimatedMinutes) * scaleFactor))
            )
        }

        let pendingMilestones = milestones.enumerated().map { index, milestone in
            AgentService.PendingMilestone(
                title: milestone.title,
                description: milestone.description,
                sequenceOrder: index,
                estimatedMinutes: 60
            )
        }

        let updatedProject = AgentService.PendingProject(
            tempId: project.tempId,
            title: title,
            mode: isPhaseMode ? "phase" : "milestone",
            archetype: isPhaseMode ? archetype : nil,
            deadline: deadlineString,
            totalPlannedMinutes: totalMinutes,
            phases: pendingPhases,
            milestones: pendingMilestones
        )

        onSave(updatedProject)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let jsonString = """
    {
        "temp_id": "preview-1",
        "title": "Chinese Reflection Essay",
        "mode": "phase",
        "archetype": "spiral",
        "deadline": "2026-02-07",
        "total_planned_minutes": 1200,
        "phases": [
            {
                "title": "Input",
                "phase_type": "divergent",
                "mental_rule": "Brainstorm freely",
                "estimated_minutes": 360
            },
            {
                "title": "Output",
                "phase_type": "convergent",
                "mental_rule": "Write messily",
                "estimated_minutes": 480
            }
        ],
        "milestones": []
    }
    """
    let data = jsonString.data(using: .utf8)!
    let project = try! JSONDecoder().decode(AgentService.PendingProject.self, from: data)

    return PendingProjectDetailSheet(
        project: project,
        onSave: { _ in },
        onDelete: {}
    )
}
