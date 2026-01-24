import SwiftUI

/// Display component for confirmed actions (stones, projects, logs).
/// Shows what was created after user confirmed - read-only, non-editable.
struct ConfirmedActionsPreview: View {
    let confirmedActions: [AgentService.PendingAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Success header with gradient
            successHeader

            // Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Confirmed stones
                let stones = confirmedActions.compactMap { $0.stone }
                if !stones.isEmpty {
                    confirmedStonesSection(stones)
                }

                // Confirmed projects
                let projects = confirmedActions.compactMap { $0.project }
                if !projects.isEmpty {
                    confirmedProjectsSection(projects)
                }

                // Confirmed logs
                let logs = confirmedActions.compactMap { $0.touchLog }
                if !logs.isEmpty {
                    confirmedLogsSection(logs)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    /// Success gradient header
    private var successHeader: some View {
        ZStack(alignment: .leading) {
            // Green gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.55, blue: 0.40),
                    Color(red: 0.28, green: 0.62, blue: 0.48),
                    Color(red: 0.35, green: 0.68, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 56)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: DesignSystem.CornerRadius.card,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: DesignSystem.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay(
                // Subtle checkmark pattern
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.06))
                            .offset(x: CGFloat(i * 60 + 20), y: CGFloat(i * 5 - 5))
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: DesignSystem.CornerRadius.card,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: DesignSystem.CornerRadius.card,
                        style: .continuous
                    )
                )
            )

            // Success badge
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Added to your schedule")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.leading, 16)
        }
    }

    // MARK: - Stones Section

    private func confirmedStonesSection(_ stones: [AgentService.PendingStone]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(stones) { stone in
                ConfirmedStoneRow(stone: stone)
            }
        }
    }

    // MARK: - Projects Section

    private func confirmedProjectsSection(_ projects: [AgentService.PendingProject]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(projects) { project in
                ConfirmedProjectRow(project: project)
            }
        }
    }

    // MARK: - Logs Section

    private func confirmedLogsSection(_ logs: [AgentService.PendingTouchLog]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(logs) { log in
                ConfirmedLogRow(log: log)
            }
        }
    }
}

// MARK: - Confirmed Stone Row

struct ConfirmedStoneRow: View {
    let stone: AgentService.PendingStone

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Success checkmark with circle background
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stone.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: stone.isRecurring ? "repeat" : "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text(stone.timeRangeString)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    if let date = stone.date {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.5))
                        Text(formatDate(date))
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    if stone.isRecurring, let recurrence = stone.recurrenceType {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.5))
                        Text(recurrence)
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                .fill(Color.green.opacity(0.05))
        )
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        return displayFormatter.string(from: date)
    }
}

// MARK: - Confirmed Project Row

struct ConfirmedProjectRow: View {
    let project: AgentService.PendingProject

    private var archetypeColor: Color {
        DesignSystem.Colors.archetypeColor(for: project.archetype)
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Success checkmark with archetype-colored background
            ZStack {
                Circle()
                    .fill(archetypeColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(archetypeColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(project.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                // Details row
                HStack(spacing: 8) {
                    if project.isPhaseMode, let archetype = project.archetype {
                        Text(archetype.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(archetypeColor))
                    }

                    if project.isPhaseMode {
                        Text("\(project.phases.count) phases")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    } else {
                        Text("\(project.milestones.count) milestones")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    if project.totalPlannedMinutes > 0 {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.5))
                        Text(formatDuration(project.totalPlannedMinutes))
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    if let deadline = project.deadline {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.5))
                        Text("Due \(formatDeadline(deadline))")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                .fill(archetypeColor.opacity(0.05))
        )
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
    }

    private func formatDeadline(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        return displayFormatter.string(from: date)
    }
}

// MARK: - Confirmed Log Row

struct ConfirmedLogRow: View {
    let log: AgentService.PendingTouchLog

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Success checkmark with green background
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let title = log.projectTitle {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                HStack(spacing: 8) {
                    Text(formatDuration(log.durationMinutes))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    if let note = log.note, !note.isEmpty {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.5))
                        Text(note)
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                .fill(Color.green.opacity(0.05))
        )
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m logged"
        } else if hours > 0 {
            return "\(hours)h logged"
        }
        return "\(mins)m logged"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ConfirmedActionsPreview(
            confirmedActions: [
                AgentService.PendingAction(
                    actionType: "add_stone",
                    stone: AgentService.PendingStone(
                        tempId: "1",
                        title: "Team Standup",
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
            ]
        )
        .padding()
    }
    .background(DesignSystem.Colors.background)
}
