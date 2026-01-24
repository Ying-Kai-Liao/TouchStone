import SwiftUI
import SwiftData

/// Detail sheet for editing a pending work log before confirmation
struct PendingLogDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let log: AgentService.PendingTouchLog
    let availableProjects: [ProjectOption]
    let onSave: (AgentService.PendingTouchLog) -> Void
    let onDelete: () -> Void

    struct ProjectOption: Identifiable, Hashable {
        let id: String
        let title: String
    }

    // Editable state
    @State private var selectedProjectId: String?
    @State private var selectedProjectTitle: String?
    @State private var durationMinutes: Int
    @State private var note: String

    @State private var showDeleteConfirmation = false

    init(
        log: AgentService.PendingTouchLog,
        availableProjects: [ProjectOption],
        onSave: @escaping (AgentService.PendingTouchLog) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.log = log
        self.availableProjects = availableProjects
        self.onSave = onSave
        self.onDelete = onDelete

        _selectedProjectId = State(initialValue: log.projectId)
        _selectedProjectTitle = State(initialValue: log.projectTitle)
        _durationMinutes = State(initialValue: log.durationMinutes)
        _note = State(initialValue: log.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Project selection
                Section("Project") {
                    Picker("Project", selection: $selectedProjectId) {
                        Text("None").tag(nil as String?)

                        ForEach(availableProjects) { project in
                            Text(project.title).tag(project.id as String?)
                        }
                    }
                    .onChange(of: selectedProjectId) { _, newId in
                        if let newId = newId,
                           let project = availableProjects.first(where: { $0.id == newId }) {
                            selectedProjectTitle = project.title
                        } else {
                            selectedProjectTitle = nil
                        }
                    }
                }

                // Duration section
                Section("Duration") {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Text("Time Worked")
                            Spacer()
                            Text(formatDuration(durationMinutes))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }

                        // Duration stepper
                        Stepper(
                            value: $durationMinutes,
                            in: 5...480,
                            step: 15
                        ) {
                            EmptyView()
                        }

                        // Quick duration buttons
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach([15, 30, 60, 90, 120], id: \.self) { minutes in
                                Button {
                                    withAnimation { durationMinutes = minutes }
                                } label: {
                                    Text(quickButtonLabel(minutes))
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(
                                            durationMinutes == minutes ? .white : DesignSystem.Colors.textSecondary
                                        )
                                        .padding(.horizontal, DesignSystem.Spacing.sm)
                                        .padding(.vertical, DesignSystem.Spacing.xs)
                                        .background(
                                            Capsule().fill(
                                                durationMinutes == minutes ? DesignSystem.Colors.accent : DesignSystem.Colors.cardBackground
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }
                }

                // Note section
                Section("Note") {
                    TextField("What did you work on?", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Delete section
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Log Entry")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Work Log")
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
                }
            }
            .confirmationDialog("Delete Log Entry?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the work log from pending actions.")
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
        return "\(mins) min"
    }

    private func quickButtonLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours)h\(mins)"
            }
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    // MARK: - Save

    private func saveChanges() {
        let updatedLog = AgentService.PendingTouchLog(
            tempId: log.tempId,
            projectId: selectedProjectId,
            projectTitle: selectedProjectTitle,
            durationMinutes: durationMinutes,
            note: note.isEmpty ? nil : note
        )

        onSave(updatedLog)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    PendingLogDetailSheet(
        log: AgentService.PendingTouchLog(
            tempId: "preview-1",
            projectId: nil,
            projectTitle: "My Book Project",
            durationMinutes: 60,
            note: "Wrote chapter 3"
        ),
        availableProjects: [
            PendingLogDetailSheet.ProjectOption(id: "1", title: "My Book Project"),
            PendingLogDetailSheet.ProjectOption(id: "2", title: "Side Hustle"),
            PendingLogDetailSheet.ProjectOption(id: "3", title: "Learning Swift"),
        ],
        onSave: { _ in },
        onDelete: {}
    )
}
