import SwiftUI

// MARK: - Day Suggested Work Section

/// Displays a section for suggested work sessions for the day.
/// Shows a "SUGGESTED WORK" header and lists each session with time period and duration.
struct DaySuggestedWorkSection: View {
    let sessions: [SuggestedSession]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            Text("SUGGESTED WORK")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            // Session rows
            ForEach(sessions) { session in
                SuggestedWorkRow(session: session)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.xl)
    }
}

// MARK: - Suggested Work Row

/// A row displaying a suggested work session.
/// Shows the time period (Morning/Afternoon/Evening), duration,
/// project title, and current phase if applicable.
struct SuggestedWorkRow: View {
    let session: SuggestedSession
    private let prefs = UserPreferences.shared

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(session.periodLabel)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text("~\(session.suggestedMinutes)m")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(width: 70, alignment: .leading)

            // Project card
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(session.project.title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                // Phase name
                if let phase = session.project.activePhase {
                    Text(phase.title)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(prefs.accentColor)
                } else if let phase = session.project.currentPhase {
                    Text(phase)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        DaySuggestedWorkSection(sessions: [])
    }
    .background(DesignSystem.Colors.background)
}
