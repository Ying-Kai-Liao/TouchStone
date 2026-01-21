import SwiftUI
import SwiftData

/// GenUI preview component for pending actions (stones, projects, logs).
/// Shows what will be created before user confirms.
struct PendingActionsPreview: View {
    let pendingActions: [AgentService.PendingAction]
    let suggestions: [String]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onSuggestionTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Pending stones
            let stones = pendingActions.compactMap { $0.stone }
            if !stones.isEmpty {
                pendingStonesSection(stones)
            }

            // Pending projects
            let projects = pendingActions.compactMap { $0.project }
            if !projects.isEmpty {
                pendingProjectsSection(projects)
            }

            // Pending touch logs
            let logs = pendingActions.compactMap { $0.touchLog }
            if !logs.isEmpty {
                pendingLogsSection(logs)
            }

            // Quick suggestions
            if !suggestions.isEmpty {
                suggestionButtons
            }

            // Confirm/Cancel buttons
            if !pendingActions.isEmpty {
                confirmationButtons
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(DesignSystem.Colors.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }

    // MARK: - Stones Section

    private func pendingStonesSection(_ stones: [AgentService.PendingStone]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Events to Add", systemImage: "calendar.badge.plus")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            ForEach(stones) { stone in
                PendingStoneRow(stone: stone)
            }
        }
    }

    // MARK: - Projects Section

    private func pendingProjectsSection(_ projects: [AgentService.PendingProject]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Projects to Create", systemImage: "folder.badge.plus")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            ForEach(projects) { project in
                PendingProjectRow(project: project)
            }
        }
    }

    // MARK: - Logs Section

    private func pendingLogsSection(_ logs: [AgentService.PendingTouchLog]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Work to Log", systemImage: "checkmark.circle.badge.plus")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            ForEach(logs) { log in
                PendingLogRow(log: log)
            }
        }
    }

    // MARK: - Suggestion Buttons

    private var suggestionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSuggestionTap(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.background)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Confirmation Buttons

    private var confirmationButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .buttonStyle(.plain)

            Button {
                onConfirm()
            } label: {
                Text("Looks Good")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .fill(DesignSystem.Colors.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }
}

// MARK: - Pending Stone Row

struct PendingStoneRow: View {
    let stone: AgentService.PendingStone

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Stone icon
            Image(systemName: stone.isRecurring ? "repeat.circle.fill" : "calendar.circle.fill")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(stone.title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(stone.timeRangeString)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    if let date = stone.date {
                        Text("on \(date)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    if stone.isRecurring, let recurrence = stone.recurrenceType {
                        Text("(\(recurrence))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Colors.background)
        )
    }
}

// MARK: - Pending Project Row

struct PendingProjectRow: View {
    let project: AgentService.PendingProject

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: archetypeIcon)
                    .font(.title2)
                    .foregroundStyle(DesignSystem.Colors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(project.archetype.uppercased())
                            .font(DesignSystem.Typography.captionBold)
                            .foregroundStyle(DesignSystem.Colors.accent)

                        Text("\(project.phases.count) phases")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        Text("\(project.totalPlannedMinutes / 60)h planned")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }

                Spacer()
            }

            // Phase summary
            ForEach(Array(project.phases.enumerated()), id: \.offset) { index, phase in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("\(index + 1).")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: 20, alignment: .trailing)

                    Text(phase.title)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("\(phase.sessions.count) sessions")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .padding(.leading, DesignSystem.Spacing.xl)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Colors.background)
        )
    }

    private var archetypeIcon: String {
        switch project.archetype.lowercased() {
        case "lab": return "flask"
        case "hunt": return "target"
        case "spiral": return "arrow.triangle.2.circlepath"
        case "build": return "hammer"
        default: return "folder"
        }
    }
}

// MARK: - Pending Log Row

struct PendingLogRow: View {
    let log: AgentService.PendingTouchLog

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                if let title = log.projectTitle {
                    Text(title)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(formattedDuration)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    if let note = log.note {
                        Text("- \(note)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Colors.background)
        )
    }

    private var formattedDuration: String {
        let hours = log.durationMinutes / 60
        let minutes = log.durationMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PendingActionsPreview(
            pendingActions: [
                AgentService.PendingAction(
                    actionType: "add_stone",
                    stone: AgentService.PendingStone(
                        tempId: "1",
                        title: "Standup",
                        startHour: 10,
                        startMinute: 0,
                        endHour: 10,
                        endMinute: 30,
                        date: "2024-01-22",
                        isRecurring: false,
                        recurrenceType: nil,
                        customDays: nil
                    ),
                    project: nil,
                    touchLog: nil
                ),
                AgentService.PendingAction(
                    actionType: "add_stone",
                    stone: AgentService.PendingStone(
                        tempId: "2",
                        title: "Dentist",
                        startHour: 15,
                        startMinute: 0,
                        endHour: 16,
                        endMinute: 0,
                        date: "2024-01-22",
                        isRecurring: false,
                        recurrenceType: nil,
                        customDays: nil
                    ),
                    project: nil,
                    touchLog: nil
                ),
            ],
            suggestions: ["Looks good", "Change times", "Cancel"],
            onConfirm: { print("Confirmed") },
            onCancel: { print("Cancelled") },
            onSuggestionTap: { print("Tapped: \($0)") }
        )
        .padding()
    }
    .background(DesignSystem.Colors.background)
}
