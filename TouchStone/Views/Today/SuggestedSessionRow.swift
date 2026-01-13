import SwiftUI
import SwiftData

/// A simple tappable block showing a suggested work session.
/// Displays project name, phase, and time slot. Tap to touch the project.
struct SuggestedSessionRow: View {
    let session: SuggestedSession
    let onTouch: () -> Void

    var body: some View {
        Button(action: onTouch) {
            HStack(spacing: 12) {
                // Time period indicator
                VStack(spacing: 2) {
                    Text(session.periodLabel)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Text("~\(session.suggestedMinutes)m")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 60)

                // Project info
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.project.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    // Phase name
                    if let phase = session.project.activePhase {
                        Text(phase.title)
                            .font(.caption)
                            .foregroundStyle(.purple)
                    } else if let phase = session.project.currentPhase {
                        Text(phase)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Touch indicator
                Image(systemName: "hand.tap")
                    .font(.caption)
                    .foregroundStyle(.blue.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
