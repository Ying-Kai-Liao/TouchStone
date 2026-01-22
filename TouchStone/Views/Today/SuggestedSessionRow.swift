import SwiftUI
import SwiftData

/// Suggested session row with tap to touch and long press or button for focus mode.
/// Handles both phase mode and milestone mode projects.
struct SuggestedSessionRow: View {
    let session: SuggestedSession
    let onTouch: () -> Void
    let onFocus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Main tappable area
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

                        // Show intention (phase or milestone based)
                        Text(session.intentionText)
                            .font(.caption)
                            .foregroundStyle(UserPreferences.shared.accentColor)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Mode indicator
                    Image(systemName: session.project.isMilestoneMode ? "checklist" : "layers.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Focus button
            Button(action: onFocus) {
                Image(systemName: "scope")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onLongPressGesture {
            onFocus()
        }
    }
}
