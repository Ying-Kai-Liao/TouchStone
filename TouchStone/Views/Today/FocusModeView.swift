import SwiftUI
import SwiftData

/// FocusModeView is an optional, minimal focus experience.
/// Rules:
/// - Must be optional (user chooses to enter)
/// - Can exit anytime
/// - No timers or progress indicators
/// - Leaving early is equal to finishing
struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let project: Project
    let onDismiss: () -> Void

    @State private var note: String = ""
    @State private var hasStarted = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Project title
                VStack(spacing: 8) {
                    Text(project.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    if let phase = project.currentPhase {
                        Text(phase)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Simple message
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

                // Exit button - always available
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
                        // Leaving early = finishing
                        finishFocus()
                    }
                }
            }
            .onAppear {
                hasStarted = true
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
