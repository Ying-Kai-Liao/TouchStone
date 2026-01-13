import SwiftUI
import SwiftData

/// A row displaying a planned session with inline editing support.
/// Shows status, title, goal, and duration with appropriate styling.
struct EditableSessionRow: View {
    @Bindable var session: PlannedSession
    let isEditing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Status indicator
                statusIcon

                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    if isEditing && session.status == .planned {
                        TextField("Session title", text: $session.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .onChange(of: session.title) { _, _ in
                                session.isManuallyEdited = true
                            }
                    } else {
                        Text(session.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .strikethrough(session.status == .skipped)
                            .foregroundStyle(session.status == .skipped ? .secondary : .primary)
                    }

                    // Goal
                    if isEditing && session.status == .planned {
                        TextField("Session goal", text: Binding(
                            get: { session.goal ?? "" },
                            set: {
                                session.goal = $0.isEmpty ? nil : $0
                                session.isManuallyEdited = true
                            }
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else if let goal = session.goal {
                        Text(goal)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    // Manual edit indicator
                    if session.isManuallyEdited && session.status == .planned {
                        Text("Manually edited")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(backgroundForStatus)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .opacity(session.status == .skipped ? 0.6 : 1.0)
        .disabled(isEditing && session.status != .planned)
    }

    // MARK: - Status Icon

    private var statusIcon: some View {
        Image(systemName: session.status.icon)
            .font(.caption)
            .foregroundStyle(colorForStatus)
            .frame(width: 20, height: 20)
    }

    private var colorForStatus: Color {
        switch session.status {
        case .planned: return .secondary
        case .completed: return .green
        case .skipped: return .orange
        }
    }

    // MARK: - Background

    private var backgroundForStatus: Color {
        switch session.status {
        case .planned: return Color(.secondarySystemGroupedBackground)
        case .completed: return Color.green.opacity(0.08)
        case .skipped: return Color.orange.opacity(0.08)
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        EditableSessionRow(
            session: PlannedSession(title: "Literature Review", goal: "Read 5 papers and take notes", estimatedMinutes: 90),
            isEditing: false,
            onTap: {}
        )

        EditableSessionRow(
            session: {
                let s = PlannedSession(title: "Draft Introduction", goal: "Write 1000 words", estimatedMinutes: 60)
                s.status = .completed
                return s
            }(),
            isEditing: false,
            onTap: {}
        )

        EditableSessionRow(
            session: {
                let s = PlannedSession(title: "Skipped Session", estimatedMinutes: 45)
                s.status = .skipped
                return s
            }(),
            isEditing: false,
            onTap: {}
        )
    }
    .modelContainer(for: PlannedSession.self, inMemory: true)
}
