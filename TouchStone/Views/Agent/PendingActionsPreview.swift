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
    var onProjectTimeChange: ((String, Int) -> Void)? = nil  // (projectId, newTotalMinutes)

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
                ProjectPreviewCard(
                    project: project,
                    onTimeChange: onProjectTimeChange
                )
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
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button {
                onConfirm()
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Looks Good")
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
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

// MARK: - Project Preview Card

/// Rich preview card for pending projects with phases/milestones
struct ProjectPreviewCard: View {
    let project: AgentService.PendingProject
    var onTimeChange: ((String, Int) -> Void)? = nil

    // Local state for slider
    @State private var sliderValue: Double = 0

    private var archetypeColor: Color {
        DesignSystem.Colors.archetypeColor(for: project.archetype)
    }

    private var totalHours: Double {
        Double(project.totalPlannedMinutes) / 60.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header: Icon + Title
            projectHeader

            // Archetype badge and deadline row
            HStack(spacing: DesignSystem.Spacing.sm) {
                if project.isPhaseMode, let archetype = project.archetype {
                    ArchetypeBadge(archetype: archetype)
                }

                if let deadline = project.deadline {
                    DeadlineBadge(deadline: deadline)
                }

                Spacer()
            }

            // Time slider (only for phase mode projects with time budgets)
            if project.isPhaseMode && project.totalPlannedMinutes > 0 {
                timeSlider
            }

            // Phases or Milestones
            if project.isPhaseMode {
                phasesSection
            } else if project.isMilestoneMode {
                milestonesSection
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Colors.background)
        )
        .onAppear {
            sliderValue = totalHours
        }
        .onChange(of: project.totalPlannedMinutes) { _, newValue in
            sliderValue = Double(newValue) / 60.0
        }
    }

    // MARK: - Time Slider

    private var timeSlider: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text("Total Time")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()

                Text(formatHours(sliderValue))
                    .font(DesignSystem.Typography.captionBold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .monospacedDigit()
            }

            Slider(
                value: $sliderValue,
                in: 1...max(totalHours * 2, 40),
                step: 0.5
            ) { editing in
                if !editing {
                    // Notify parent when user finishes dragging
                    let newMinutes = Int(sliderValue * 60)
                    onTimeChange?(project.id, newMinutes)
                }
            }
            .tint(archetypeColor)

            // Quick time buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach([5, 10, 20, 40], id: \.self) { hours in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sliderValue = Double(hours)
                        }
                        onTimeChange?(project.id, hours * 60)
                    } label: {
                        Text("\(hours)h")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(
                                abs(sliderValue - Double(hours)) < 0.5
                                    ? .white
                                    : DesignSystem.Colors.textSecondary
                            )
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(
                                        abs(sliderValue - Double(hours)) < 0.5
                                            ? archetypeColor
                                            : DesignSystem.Colors.cardBackground
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private func formatHours(_ hours: Double) -> String {
        let wholeHours = Int(hours)
        let minutes = Int((hours - Double(wholeHours)) * 60)
        if minutes > 0 {
            return "\(wholeHours)h \(minutes)m"
        }
        return "\(wholeHours) hours"
    }

    // MARK: - Header

    private var projectHeader: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: modeIcon)
                .font(.title2)
                .foregroundStyle(archetypeColor)

            Text(project.title)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()
        }
    }

    // MARK: - Phases Section

    private var phasesSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(project.phases.enumerated()), id: \.offset) { index, phase in
                PhaseCard(
                    phase: phase,
                    index: index,
                    totalMinutes: max(project.totalPlannedMinutes, 1),
                    archetypeColor: archetypeColor
                )
            }
        }
    }

    // MARK: - Milestones Section

    private var milestonesSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(project.milestones.enumerated()), id: \.offset) { index, milestone in
                PendingMilestoneRow(milestone: milestone, index: index)
            }
        }
    }

    // MARK: - Total Summary (for milestone mode only)

    private var totalSummary: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Divider()
                .background(DesignSystem.Colors.divider)

            HStack {
                Text("Total:")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Spacer()

                Text("\(project.milestones.count) milestones")
                    .font(DesignSystem.Typography.captionBold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .padding(.top, DesignSystem.Spacing.xs)
        }
    }

    // MARK: - Helpers

    private var modeIcon: String {
        if project.isMilestoneMode {
            return "checklist"
        }
        guard let archetype = project.archetype else { return "folder" }
        switch archetype.lowercased() {
        case "lab": return "flask"
        case "hunt": return "target"
        case "spiral": return "arrow.triangle.2.circlepath"
        case "build": return "hammer"
        default: return "folder"
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours) hours"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Phase Card

/// Individual phase card showing title, mental rule, and time allocation
struct PhaseCard: View {
    let phase: AgentService.PendingPhase
    let index: Int
    let totalMinutes: Int
    let archetypeColor: Color

    private var percentage: Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(phase.estimatedMinutes) / Double(totalMinutes)
    }

    private var percentageText: String {
        "\(Int(percentage * 100))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Phase header: Number + Title + Hours
            HStack {
                Text("Phase \(index + 1): \(phase.title)")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                Text(formatDuration(phase.estimatedMinutes))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            // Mental rule (quoted, styled)
            Text("\"\(phase.mentalRule)\"")
                .font(DesignSystem.Typography.caption)
                .italic()
                .foregroundStyle(DesignSystem.Colors.accent)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Progress bar showing % of total
            HStack(spacing: DesignSystem.Spacing.sm) {
                TimeProgressBar(value: percentage, color: archetypeColor)

                Text(percentageText)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(archetypeColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Time Progress Bar

/// Visual progress bar for time allocation
struct TimeProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignSystem.Colors.divider)

                // Filled portion
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Archetype Badge

/// Visual badge showing project archetype
struct ArchetypeBadge: View {
    let archetype: String

    private var color: Color {
        DesignSystem.Colors.archetypeColor(for: archetype)
    }

    var body: some View {
        Text(archetype.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

// MARK: - Deadline Badge

/// Prominent deadline display
struct DeadlineBadge: View {
    let deadline: String

    private var formattedDeadline: String {
        // Parse and format the deadline
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let date = formatter.date(from: deadline) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        return deadline
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "calendar")
                .font(.system(size: 10))
            Text("Due: \(formattedDeadline)")
                .font(DesignSystem.Typography.caption)
        }
        .foregroundStyle(DesignSystem.Colors.textSecondary)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Pending Milestone Row

/// Row for displaying a pending milestone item in preview (pure todo list style - no time)
struct PendingMilestoneRow: View {
    let milestone: AgentService.PendingMilestone
    let index: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Checkbox circle
            Circle()
                .stroke(DesignSystem.Colors.border, lineWidth: 1.5)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                if let description = milestone.description, !description.isEmpty {
                    Text(description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Colors.cardBackground)
        )
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

// MARK: - Legacy Support (kept for backward compatibility)

struct PendingProjectRow: View {
    let project: AgentService.PendingProject

    var body: some View {
        ProjectPreviewCard(project: project)
    }
}

// MARK: - Preview

#Preview("Project with Phases") {
    ScrollView {
        PendingActionsPreview(
            pendingActions: [
                AgentService.PendingAction(
                    actionType: "add_project",
                    stone: nil,
                    project: previewPhaseProject,
                    touchLog: nil
                ),
            ],
            suggestions: ["More time", "Fewer phases", "Change deadline"],
            onConfirm: { print("Confirmed") },
            onCancel: { print("Cancelled") },
            onSuggestionTap: { print("Tapped: \($0)") }
        )
        .padding()
    }
    .background(DesignSystem.Colors.background)
}

#Preview("Project with Milestones") {
    ScrollView {
        PendingActionsPreview(
            pendingActions: [
                AgentService.PendingAction(
                    actionType: "add_project",
                    stone: nil,
                    project: previewMilestoneProject,
                    touchLog: nil
                ),
            ],
            suggestions: ["Add more steps", "Change order"],
            onConfirm: { print("Confirmed") },
            onCancel: { print("Cancelled") },
            onSuggestionTap: { print("Tapped: \($0)") }
        )
        .padding()
    }
    .background(DesignSystem.Colors.background)
}

#Preview("Stones") {
    VStack(spacing: 20) {
        PendingActionsPreview(
            pendingActions: [
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
                        isRecurring: true,
                        recurrenceType: "weekdays",
                        customDays: nil
                    ),
                    project: nil,
                    touchLog: nil
                ),
            ],
            suggestions: ["Looks good", "Change time"],
            onConfirm: { print("Confirmed") },
            onCancel: { print("Cancelled") },
            onSuggestionTap: { print("Tapped: \($0)") }
        )
        .padding()
    }
    .background(DesignSystem.Colors.background)
}

// MARK: - Preview Data

private var previewPhaseProject: AgentService.PendingProject {
    let jsonString = """
    {
        "temp_id": "preview-1",
        "title": "Chinese Reflection Essay",
        "mode": "phase",
        "archetype": "spiral",
        "deadline": "2026-02-07",
        "total_planned_minutes": 1200,
        "phases": [
            {
                "title": "Input",
                "phase_type": "divergent",
                "mental_rule": "Brainstorm freely. Think about your experiences in modern society and how they connect to traditional values.",
                "estimated_minutes": 360
            },
            {
                "title": "Output",
                "phase_type": "convergent",
                "mental_rule": "Write messily. Get 2000+ words down without worrying about grammar or structure.",
                "estimated_minutes": 480
            },
            {
                "title": "Reflection",
                "phase_type": "polish",
                "mental_rule": "Polish your Chinese. Fix grammar, improve word choice, and ensure cultural references are accurate.",
                "estimated_minutes": 360
            }
        ],
        "milestones": []
    }
    """
    let data = jsonString.data(using: .utf8)!
    return try! JSONDecoder().decode(AgentService.PendingProject.self, from: data)
}

private var previewMilestoneProject: AgentService.PendingProject {
    let jsonString = """
    {
        "temp_id": "preview-2",
        "title": "File 2025 Taxes",
        "mode": "milestone",
        "archetype": null,
        "deadline": "2026-04-15",
        "total_planned_minutes": 300,
        "phases": [],
        "milestones": [
            {
                "title": "Gather W-2 forms",
                "description": "From all employers",
                "sequence_order": 1,
                "estimated_minutes": 30
            },
            {
                "title": "Collect 1099 forms",
                "description": "Investment income, freelance work",
                "sequence_order": 2,
                "estimated_minutes": 45
            },
            {
                "title": "Organize receipts for deductions",
                "description": null,
                "sequence_order": 3,
                "estimated_minutes": 60
            },
            {
                "title": "Complete tax software entry",
                "description": "Use TurboTax or similar",
                "sequence_order": 4,
                "estimated_minutes": 120
            },
            {
                "title": "Review and file",
                "description": null,
                "sequence_order": 5,
                "estimated_minutes": 45
            }
        ]
    }
    """
    let data = jsonString.data(using: .utf8)!
    return try! JSONDecoder().decode(AgentService.PendingProject.self, from: data)
}
