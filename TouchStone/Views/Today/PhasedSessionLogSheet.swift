import SwiftUI
import SwiftData

/// Simplified touch logging sheet for both phase and milestone mode projects.
/// Logs time invested without session-level tracking.
struct PhasedSessionLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let project: Project
    let onLog: (TouchLog) -> Void

    @State private var selectedDuration: Int = 60
    @State private var note: String = ""

    private let durationOptions = [30, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Project header
                    projectHeader

                    // Context card (phase or milestone)
                    contextCard

                    // Duration picker
                    durationPicker

                    // Note field
                    noteField

                    // Log button
                    logButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Log Work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Project Header

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.title)
                    .font(.title2)
                    .fontWeight(.bold)

                // Mode badge
                Text(project.isPhaseMode ? "PHASE" : "MILESTONE")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(UserPreferences.shared.accentColor.opacity(0.15))
                    .clipShape(Capsule())

                if let archetype = project.archetype {
                    Text(archetype.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Context Card

    @ViewBuilder
    private var contextCard: some View {
        if project.isPhaseMode, let phase = project.activePhase {
            // Phase mode context
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: phase.phaseType.icon)
                        .foregroundStyle(UserPreferences.shared.accentColor)
                    Text(phase.title)
                        .font(.headline)
                    Spacer()
                    Text(phase.progressString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let rule = phase.mentalRule {
                    HStack(alignment: .top) {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(UserPreferences.shared.accentColor.opacity(0.7))
                        Text("\"\(rule)\"")
                            .italic()
                            .foregroundStyle(UserPreferences.shared.accentColor)
                    }
                    .font(.subheadline)
                }

                // Progress bar
                ProgressView(value: phase.progress)
                    .tint(UserPreferences.shared.accentColor)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UserPreferences.shared.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if project.isMilestoneMode, let milestone = project.nextMilestone {
            // Milestone mode context
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "circle")
                        .foregroundStyle(UserPreferences.shared.accentColor)
                    Text("Next: \(milestone.title)")
                        .font(.headline)
                }

                if let description = milestone.descriptionText {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Progress
                let completed = project.completedMilestoneCount
                let total = project.milestones.count
                if total > 0 {
                    HStack {
                        Text("\(completed) of \(total) milestones completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UserPreferences.shared.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(durationOptions, id: \.self) { duration in
                    Button {
                        selectedDuration = duration
                    } label: {
                        Text(formatDuration(duration))
                            .font(.subheadline)
                            .fontWeight(selectedDuration == duration ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedDuration == duration ? UserPreferences.shared.accentColor : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(selectedDuration == duration ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "~\(minutes)m"
        } else if minutes == 60 {
            return "~1h"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "~\(hours)h \(mins)m" : "~\(hours)h"
        }
    }

    // MARK: - Note Field

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $note)
                .frame(height: 80)
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            logWork()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Log Work")
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(UserPreferences.shared.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private func logWork() {
        let touch = TouchLog(
            durationMinutes: selectedDuration,
            note: note.isEmpty ? nil : note,
            project: project
        )

        // Link to active phase if in phase mode
        if project.isPhaseMode, let phase = project.activePhase {
            touch.phase = phase
        }

        onLog(touch)
        dismiss()
    }
}

#Preview("Phase Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, ProjectPhase.self, Milestone.self, TouchLog.self, configurations: config)

    let project = Project(title: "Research Paper", archetype: .lab)
    container.mainContext.insert(project)

    let phase = ProjectPhase(
        title: "Exploration",
        phaseType: .divergent,
        mentalRule: "Explore widely, no conclusions yet",
        sequenceOrder: 0,
        estimatedMinutes: 180
    )
    phase.project = project
    container.mainContext.insert(phase)
    project.phases = [phase]

    return PhasedSessionLogSheet(project: project) { _ in }
        .modelContainer(container)
}

#Preview("Milestone Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, ProjectPhase.self, Milestone.self, TouchLog.self, configurations: config)

    let project = Project(title: "Tax Filing 2025", mode: .milestone)
    container.mainContext.insert(project)

    let milestone = Milestone(title: "Gather W2s and 1099s", descriptionText: "Collect all income documents")
    milestone.project = project
    container.mainContext.insert(milestone)
    project.milestones = [milestone]

    return PhasedSessionLogSheet(project: project) { _ in }
        .modelContainer(container)
}
