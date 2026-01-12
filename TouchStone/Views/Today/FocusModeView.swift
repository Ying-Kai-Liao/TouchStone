import SwiftUI
import SwiftData

/// FocusModeView is an optional, minimal focus experience.
/// Per STATE_MACHINE.md:
/// - Shows: Project name + phase + short goal line
/// - Soft time container (~1h) without strict countdown
/// - Can exit anytime (leaving early = finishing)
struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let project: Project
    let onDismiss: () -> Void

    @State private var note: String = ""

    /// Short goal line - either from next session or phase
    var shortGoalLine: String? {
        if let session = project.nextPlannedSession {
            return session.title
        }
        if let phase = project.activePhase {
            return phase.title
        }
        return project.currentPhase
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Project name
                Text(project.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Phase + short goal (minimal per guardrails)
                if let goal = shortGoalLine {
                    Text(goal)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Focus message
                Text("Focus on this.\nEverything else can wait.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                // Optional note
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("What are you working on?", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
                .padding(.horizontal)

                Spacer()

                // Single Done button - leaving early = finishing (per guardrails)
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
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Focus Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Leaving early = finishing (per guardrails)
                        finishFocus()
                    }
                }
            }
        }
    }

    private func finishFocus() {
        // Log touch regardless of how long they focused
        let touch = TouchLog(
            durationMinutes: 60,  // Default ~1h, doesn't matter
            note: note.isEmpty ? nil : note,
            project: project
        )
        modelContext.insert(touch)
        onDismiss()
    }
}

#Preview {
    FocusModeView(
        project: Project(title: "Q4 Strategy", currentPhase: "Discovery"),
        onDismiss: {}
    )
}
