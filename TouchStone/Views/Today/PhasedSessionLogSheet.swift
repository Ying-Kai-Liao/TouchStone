import SwiftUI
import SwiftData

struct PhasedSessionLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let project: Project
    let onLog: (TouchLog) -> Void

    @State private var selectedDuration: Int = 60
    @State private var note: String = ""

    private let durationOptions = [30, 60, 90, 120]

    var nextSession: PlannedSession? {
        project.nextPlannedSession
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Project header
                    projectHeader

                    // Session context
                    if let session = nextSession {
                        sessionContext(session)
                    }

                    // Duration picker
                    durationPicker

                    // Note field
                    noteField

                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Log Session")
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

                if let archetype = project.archetype {
                    Text(archetype.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if let phase = project.activePhase {
                HStack {
                    Image(systemName: phase.phaseType.icon)
                        .foregroundStyle(Color.purple)
                    Text("Phase: \(phase.title)")
                        .foregroundStyle(.secondary)
                    Text("(\(phase.progressString))")
                        .foregroundStyle(.tertiary)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Session Context

    private func sessionContext(_ session: PlannedSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Session title
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(Color.purple)
                Text(session.title)
                    .font(.headline)
            }

            // Mental rule
            if let rule = session.mentalRule {
                HStack(alignment: .top) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(Color.purple.opacity(0.7))
                    Text("\"\(rule)\"")
                        .italic()
                        .foregroundStyle(Color.purple)
                }
                .font(.subheadline)
            }

            // Goal
            if let goal = session.goal {
                HStack(alignment: .top) {
                    Image(systemName: "flag")
                        .foregroundStyle(.secondary)
                    Text("Goal: \(goal)")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                            .background(selectedDuration == duration ? Color.purple : Color(.secondarySystemGroupedBackground))
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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Mark session complete
            if nextSession != nil {
                Button {
                    markSessionComplete()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark Session Complete")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Just log touch
            Button {
                justLogTouch()
            } label: {
                Text("Just Log Touch")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Skip session
            if nextSession != nil {
                Button {
                    skipSession()
                } label: {
                    Text("Skip This Session")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func markSessionComplete() {
        let touch = TouchLog(
            durationMinutes: selectedDuration,
            note: note.isEmpty ? nil : note,
            project: project
        )

        if let session = nextSession {
            session.markComplete(with: touch)
        }

        onLog(touch)
        dismiss()
    }

    private func justLogTouch() {
        let touch = TouchLog(
            durationMinutes: selectedDuration,
            note: note.isEmpty ? nil : note,
            project: project
        )

        onLog(touch)
        dismiss()
    }

    private func skipSession() {
        nextSession?.markSkipped()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)

    let project = Project(title: "Test Project")
    container.mainContext.insert(project)

    return PhasedSessionLogSheet(project: project) { _ in }
        .modelContainer(container)
}
