import SwiftUI

// MARK: - Day Projects Due Section

/// Displays a section for projects that have deadlines on the current day.
/// Shows a "DUE TODAY" header with a warning icon and lists each project.
struct DayProjectsDueSection: View {
    let projects: [Project]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            HStack {
                Text("DUE TODAY")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1)

                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

            // Project rows
            ForEach(projects) { project in
                ProjectDueRow(project: project)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.xl)
    }
}

// MARK: - Project Due Row

/// A row displaying a project that is due today.
/// Shows a deadline indicator icon, project title, deadline time, and current phase.
struct ProjectDueRow: View {
    let project: Project

    private var formattedDeadline: String {
        guard let deadline = project.deadline else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: deadline)
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Deadline indicator
            VStack(alignment: .center, spacing: 2) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text("DUE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            .frame(width: 70)

            // Project card
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(project.title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text(formattedDeadline)
                        .font(DesignSystem.Typography.caption)

                    if let phase = project.activePhase {
                        Text("•")
                        Text(phase.title)
                            .font(DesignSystem.Typography.caption)
                    } else if let phase = project.currentPhase {
                        Text("•")
                        Text(phase)
                            .font(DesignSystem.Typography.caption)
                    }
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                    .fill(DesignSystem.Colors.accent.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1.5)
            )
            // Shadow elevation level 3 for critical deadlines
            .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        DayProjectsDueSection(projects: [])
    }
    .background(DesignSystem.Colors.background)
}
