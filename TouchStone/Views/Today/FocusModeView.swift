import SwiftUI
import SwiftData

/// FocusModeView is an optional, minimal focus experience.
/// Rules:
/// - Must be optional (user chooses to enter)
/// - Can exit anytime
/// - No timers or progress indicators
/// - Leaving early is equal to finishing
///
/// For strategic projects, shows detailed context:
/// - Phase guardrails (mental rules)
/// - Current session title and goal
struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let project: Project
    let onDismiss: () -> Void

    @State private var note: String = ""
    @State private var hasStarted = false

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
                    // Project header
                    projectHeader

                    // Strategic project context
                    if project.hasStrategicPlan {
                        strategicContext
                    }

                    // Focus message
                    focusMessage

                    // Note field
                    noteField
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                doneButton
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Focus Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Exit") {
                        finishFocus(markSessionComplete: false)
                    }
                }
            }
            .onAppear {
                hasStarted = true
            }
        }
    }

    // MARK: - Project Header

    private var projectHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text(project.title)
                    .font(.title)
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

            // Simple phase for non-strategic projects
            if !project.hasStrategicPlan, let phase = project.currentPhase {
                Text(phase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Strategic Context

    @ViewBuilder
    private var strategicContext: some View {
        VStack(spacing: 16) {
            // Phase guardrails
            if let phase = activePhase {
                phaseGuardrailCard(phase: phase)
            }

            // Current session details
            if let session = currentSession {
                sessionDetailCard(session: session)
            }

            // Progress
            progressCard
        }
    }

    private func phaseGuardrailCard(phase: ProjectPhase) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: phase.phaseType.icon)
                    .foregroundStyle(.orange)
                Text("Phase: \(phase.title)")
                    .font(.headline)
                Spacer()
                Text("\(phase.completedSessionCount)/\(phase.totalSessionCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let rule = phase.mentalRule {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mental Rule")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\"\(rule)\"")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .italic()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sessionDetailCard(session: PlannedSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(Color.purple)
                Text("Current Session")
                    .font(.headline)
                Spacer()
                Text(session.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(session.title)
                .font(.title3)
                .fontWeight(.semibold)

            if let goal = session.goal {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(goal)
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overall Progress")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(project.progressString)
                    .font(.subheadline)
                    .foregroundStyle(Color.purple)
            }

            ProgressView(value: project.progress)
                .tint(.purple)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Focus Message

    private var focusMessage: some View {
        Text("Focus on this.\nEverything else can wait.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
    }

    // MARK: - Note Field

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (optional)")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("What did you accomplish?", text: $note, axis: .vertical)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(2...4)
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        VStack(spacing: 12) {
            if project.hasStrategicPlan && currentSession != nil {
                // Option to mark session complete
                Button {
                    finishFocus(markSessionComplete: true)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark Session Complete")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    finishFocus(markSessionComplete: false)
                } label: {
                    Text("Just Log Touch")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    finishFocus(markSessionComplete: false)
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func finishFocus(markSessionComplete: Bool) {
        let touch = TouchLog(
            durationMinutes: currentSession?.estimatedMinutes ?? 60,
            note: note.isEmpty ? nil : note,
            project: project
        )
        modelContext.insert(touch)

        if markSessionComplete, let session = currentSession {
            session.markComplete(with: touch)
        }

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
