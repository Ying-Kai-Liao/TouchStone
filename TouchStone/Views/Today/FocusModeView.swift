import SwiftUI
import SwiftData

/// FocusModeView is an optional, minimal focus experience.
/// Per STATE_MACHINE.md:
/// - Shows: Project name + phase + short goal line
/// - Soft time container (~1h) without strict countdown
/// - Can exit anytime (leaving early = finishing)
///
/// Phase goal is collapsible, session goal is very subtle (only visible when wanted)
struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let project: Project
    let onDismiss: () -> Void

    @State private var note: String = ""
    @State private var showPhaseDetails = false
    @State private var showSessionGoal = false

    var activePhase: ProjectPhase? {
        project.activePhase
    }

    var currentSession: PlannedSession? {
        project.nextPlannedSession
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // Project name
                    Text(project.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    // Phase name (tap to expand details)
                    if let phase = activePhase {
                        phaseSection(phase: phase)
                    } else if let phase = project.currentPhase {
                        Text(phase)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Focus message
                    Text("Focus on this.\nEverything else can wait.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    Spacer(minLength: 20)

                    // Session goal hint (very subtle)
                    if let session = currentSession {
                        sessionHint(session: session)
                    }

                    // Optional note
                    noteSection

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .bottom) {
                doneButton
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Focus Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        finishFocus()
                    }
                }
            }
        }
    }

    // MARK: - Phase Section (Collapsible)

    private func phaseSection(phase: ProjectPhase) -> some View {
        VStack(spacing: 8) {
            // Phase name - tap to expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPhaseDetails.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(phase.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if phase.mentalRule != nil {
                        Image(systemName: showPhaseDetails ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Collapsible phase goal/mental rule
            if showPhaseDetails, let rule = phase.mentalRule {
                Text("\"\(rule)\"")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    // MARK: - Session Hint (Very Subtle)

    private func sessionHint(session: PlannedSession) -> some View {
        VStack(spacing: 4) {
            // Very subtle tap hint
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSessionGoal.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb")
                        .font(.caption2)
                    Text("session suggestion")
                        .font(.caption2)
                    Image(systemName: showSessionGoal ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.quaternary)
            }
            .buttonStyle(.plain)

            // Hidden session goal - only shows when tapped
            if showSessionGoal {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.title)
                        .font(.caption)
                        .fontWeight(.medium)

                    if let goal = session.goal {
                        Text(goal)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (optional)")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("What are you working on?", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
        .padding(.horizontal)
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            finishFocus()
        } label: {
            Text("Done")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func finishFocus() {
        let touch = TouchLog(
            durationMinutes: 60,
            note: note.isEmpty ? nil : note,
            project: project
        )
        modelContext.insert(touch)
        onDismiss()
    }
}

#Preview("Simple Project") {
    FocusModeView(
        project: Project(title: "Q4 Strategy", currentPhase: "Discovery"),
        onDismiss: {}
    )
}

#Preview("Strategic Project") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, ProjectPhase.self, PlannedSession.self, configurations: config)

    let project = Project(title: "Research Paper", archetype: .lab)
    container.mainContext.insert(project)

    let phase = ProjectPhase(
        title: "Exploration",
        phaseType: .divergent,
        mentalRule: "Explore widely, no conclusions yet",
        sequenceOrder: 0
    )
    phase.project = project
    container.mainContext.insert(phase)

    let session = PlannedSession(
        title: "Literature Safari",
        goal: "Find and bookmark 15 related papers on ML optimization",
        estimatedMinutes: 90,
        sequenceOrder: 0
    )
    session.phase = phase
    container.mainContext.insert(session)

    project.phases = [phase]
    phase.sessions = [session]

    return FocusModeView(project: project, onDismiss: {})
        .modelContainer(container)
}
