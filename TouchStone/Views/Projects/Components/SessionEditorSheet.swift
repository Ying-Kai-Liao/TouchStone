import SwiftUI
import SwiftData

/// Full editor sheet for a planned session.
/// Shows title, goal, and phase context.
struct SessionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: PlannedSession

    var body: some View {
        NavigationStack {
            Form {
                // Session details section
                Section("Session Details") {
                    TextField("Title", text: $session.title)
                        .disabled(session.status != .planned)

                    TextField("Goal", text: Binding(
                        get: { session.goal ?? "" },
                        set: { session.goal = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(2...4)
                    .disabled(session.status != .planned)
                }

                // Status section
                Section("Status") {
                    HStack {
                        Image(systemName: session.status.icon)
                            .foregroundStyle(statusColor)
                        Text(session.status.displayName)

                        Spacer()

                        if session.isManuallyEdited {
                            Text("Edited")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    if session.status == .planned {
                        // Action buttons for planned sessions
                        Button {
                            session.markComplete()
                            dismiss()
                        } label: {
                            Label("Mark Complete", systemImage: "checkmark.circle")
                        }
                        .tint(.green)

                        Button {
                            session.markSkipped()
                            dismiss()
                        } label: {
                            Label("Skip Session", systemImage: "arrow.right.circle")
                        }
                        .tint(.orange)
                    }

                    if let completedAt = session.completedAt {
                        LabeledContent("Completed") {
                            Text(completedAt, style: .date)
                        }
                    }
                }

                // Phase context section
                if let phase = session.phase {
                    Section("Phase Context") {
                        LabeledContent("Phase", value: phase.title)
                        LabeledContent("Type", value: phase.phaseType.displayName)

                        if let rule = phase.mentalRule {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Mental Rule")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\"\(rule)\"")
                                    .italic()
                                    .foregroundStyle(UserPreferences.shared.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if session.status == .planned {
                            session.isManuallyEdited = true
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch session.status {
        case .planned: return .secondary
        case .completed: return .green
        case .skipped: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    SessionEditorSheet(
        session: PlannedSession(title: "Research Session", goal: "Review 5 papers on the topic", estimatedMinutes: 90)
    )
    .modelContainer(for: PlannedSession.self, inMemory: true)
}
