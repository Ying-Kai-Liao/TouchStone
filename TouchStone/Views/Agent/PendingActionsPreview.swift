import SwiftUI
import SwiftData

/// GenUI preview component for pending actions (stones, projects, logs).
/// Shows what will be created before user confirms.
/// Tapping on items opens detail sheets for editing.
struct PendingActionsPreview: View {
    let pendingActions: [AgentService.PendingAction]
    let suggestions: [String]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onSuggestionTap: (String) -> Void
    var onProjectTimeChange: ((String, Int) -> Void)? = nil  // (projectId, newTotalMinutes)
    var onActionUpdate: ((Int, AgentService.PendingAction) -> Void)? = nil  // (index, updatedAction)
    var onActionDelete: ((Int) -> Void)? = nil  // (index)
    var availableProjects: [PendingLogDetailSheet.ProjectOption] = []  // For log editing
    var hasUserEdits: Bool = false  // Whether user has made local edits

    // Sheet presentation state
    @State private var selectedStoneIndex: Int?
    @State private var selectedProjectIndex: Int?
    @State private var selectedLogIndex: Int?

    /// Words/phrases that indicate confirmation-like suggestions which duplicate the confirm/cancel buttons
    private static let confirmationKeywords: Set<String> = [
        "looks good", "lgtm", "confirm", "yes", "ok", "okay", "approve",
        "cancel", "no", "reject", "nevermind", "never mind", "stop"
    ]

    /// Filtered suggestions that exclude confirmation-like phrases to avoid button duplication
    private var filteredSuggestions: [String] {
        suggestions.filter { suggestion in
            let lowercased = suggestion.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return !Self.confirmationKeywords.contains(lowercased)
        }
    }

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

            // Quick suggestions (filtered to remove confirmation-like duplicates)
            if !filteredSuggestions.isEmpty {
                suggestionButtons
            }

            // Confirm/Cancel buttons
            if !pendingActions.isEmpty {
                confirmationButtons
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Stones Section

    private func pendingStonesSection(_ stones: [AgentService.PendingStone]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Events to Add", systemImage: "calendar.badge.plus")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            ForEach(Array(stones.enumerated()), id: \.element.id) { index, stone in
                PendingStoneRow(stone: stone)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Find the index in the original pendingActions array
                        if let actionIndex = findActionIndex(for: stone) {
                            selectedStoneIndex = actionIndex
                        }
                    }
            }
        }
        .sheet(item: Binding(
            get: { selectedStoneIndex.map { StoneSheetItem(index: $0) } },
            set: { selectedStoneIndex = $0?.index }
        )) { item in
            if let stone = pendingActions[safe: item.index]?.stone {
                PendingStoneDetailSheet(
                    stone: stone,
                    onSave: { updatedStone in
                        let updatedAction = AgentService.PendingAction(
                            actionType: "add_stone",
                            stone: updatedStone,
                            project: nil,
                            touchLog: nil
                        )
                        onActionUpdate?(item.index, updatedAction)
                    },
                    onDelete: {
                        onActionDelete?(item.index)
                    }
                )
            }
        }
    }

    /// Find the index of an action containing a specific stone
    private func findActionIndex(for stone: AgentService.PendingStone) -> Int? {
        pendingActions.firstIndex { $0.stone?.id == stone.id }
    }

    // MARK: - Projects Section

    private func pendingProjectsSection(_ projects: [AgentService.PendingProject]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Projects to Create", systemImage: "folder.badge.plus")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                ProjectPreviewCard(
                    project: project,
                    onTimeChange: onProjectTimeChange
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if let actionIndex = findActionIndex(for: project) {
                        selectedProjectIndex = actionIndex
                    }
                }
            }
        }
        .sheet(item: Binding(
            get: { selectedProjectIndex.map { ProjectSheetItem(index: $0) } },
            set: { selectedProjectIndex = $0?.index }
        )) { item in
            if let project = pendingActions[safe: item.index]?.project {
                PendingProjectDetailSheet(
                    project: project,
                    onSave: { updatedProject in
                        let updatedAction = AgentService.PendingAction(
                            actionType: "add_project",
                            stone: nil,
                            project: updatedProject,
                            touchLog: nil
                        )
                        onActionUpdate?(item.index, updatedAction)
                    },
                    onDelete: {
                        onActionDelete?(item.index)
                    }
                )
            }
        }
    }

    /// Find the index of an action containing a specific project
    private func findActionIndex(for project: AgentService.PendingProject) -> Int? {
        pendingActions.firstIndex { $0.project?.id == project.id }
    }

    // MARK: - Logs Section

    private func pendingLogsSection(_ logs: [AgentService.PendingTouchLog]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label("Work to Log", systemImage: "checkmark.circle.badge.plus")
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                PendingLogRow(log: log)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let actionIndex = findActionIndex(for: log) {
                            selectedLogIndex = actionIndex
                        }
                    }
            }
        }
        .sheet(item: Binding(
            get: { selectedLogIndex.map { LogSheetItem(index: $0) } },
            set: { selectedLogIndex = $0?.index }
        )) { item in
            if let log = pendingActions[safe: item.index]?.touchLog {
                PendingLogDetailSheet(
                    log: log,
                    availableProjects: availableProjects,
                    onSave: { updatedLog in
                        let updatedAction = AgentService.PendingAction(
                            actionType: "log_work",
                            stone: nil,
                            project: nil,
                            touchLog: updatedLog
                        )
                        onActionUpdate?(item.index, updatedAction)
                    },
                    onDelete: {
                        onActionDelete?(item.index)
                    }
                )
            }
        }
    }

    /// Find the index of an action containing a specific log
    private func findActionIndex(for log: AgentService.PendingTouchLog) -> Int? {
        pendingActions.firstIndex { $0.touchLog?.id == log.id }
    }

    // MARK: - Suggestion Buttons

    private var suggestionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(filteredSuggestions, id: \.self) { suggestion in
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
        HStack(spacing: 12) {
            // Cancel button - subtle outline style
            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                            .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            // Confirm button - prominent accent style
            Button {
                onConfirm()
            } label: {
                HStack(spacing: 6) {
                    Text(hasUserEdits ? "Save Changes" : "Looks Good")
                    Image(systemName: hasUserEdits ? "square.and.arrow.down" : "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.accent,
                                    DesignSystem.Colors.accent.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, DesignSystem.Spacing.md)
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
        VStack(alignment: .leading, spacing: 0) {
            // Project gradient header
            projectGradientHeader
                .padding(.horizontal, 8)
                .padding(.top, 8)

            // Content section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Title
                Text(project.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

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
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            sliderValue = totalHours
        }
        .onChange(of: project.totalPlannedMinutes) { _, newValue in
            sliderValue = Double(newValue) / 60.0
        }
    }

    /// Project gradient header with archetype-based coloring
    private var projectGradientHeader: some View {
        ZStack(alignment: .topLeading) {
            // Gradient background based on archetype
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 72)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card - 8, style: .continuous))
            .overlay(
                // Decorative pattern
                ZStack {
                    if project.isMilestoneMode {
                        // Checklist pattern for milestones
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 40, height: 3)
                                .offset(x: CGFloat(i * 50 - 60), y: CGFloat(i * 8 - 12))
                        }
                    } else {
                        // Wave pattern for projects
                        ForEach(0..<4, id: \.self) { i in
                            ProjectWaveShape(offset: CGFloat(i) * 10, amplitude: 4)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                .offset(y: CGFloat(i) * 8 + 20)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card - 8, style: .continuous))
            )

            // Mode badge - glassy style
            HStack(spacing: 6) {
                Image(systemName: modeIcon)
                    .font(.system(size: 10, weight: .semibold))
                Text(project.isMilestoneMode ? "CHECKLIST" : (project.archetype?.uppercased() ?? "PROJECT"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.2))
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            )
            .padding(10)
        }
    }

    /// Gradient colors based on archetype
    private var gradientColors: [Color] {
        guard let archetype = project.archetype?.lowercased() else {
            // Default gray for milestone mode
            return [
                Color(red: 0.35, green: 0.38, blue: 0.42),
                Color(red: 0.45, green: 0.48, blue: 0.52),
                Color(red: 0.50, green: 0.53, blue: 0.58)
            ]
        }
        switch archetype {
        case "lab":
            return [
                Color(red: 0.25, green: 0.45, blue: 0.65),
                Color(red: 0.35, green: 0.55, blue: 0.72),
                Color(red: 0.42, green: 0.62, blue: 0.78)
            ]
        case "hunt":
            return [
                Color(red: 0.75, green: 0.45, blue: 0.25),
                Color(red: 0.82, green: 0.55, blue: 0.35),
                Color(red: 0.88, green: 0.62, blue: 0.42)
            ]
        case "spiral":
            return [
                Color(red: 0.55, green: 0.35, blue: 0.65),
                Color(red: 0.62, green: 0.42, blue: 0.72),
                Color(red: 0.68, green: 0.48, blue: 0.78)
            ]
        case "build":
            return [
                Color(red: 0.30, green: 0.55, blue: 0.45),
                Color(red: 0.38, green: 0.62, blue: 0.52),
                Color(red: 0.45, green: 0.68, blue: 0.58)
            ]
        default:
            return [
                Color(red: 0.35, green: 0.50, blue: 0.55),
                Color(red: 0.45, green: 0.58, blue: 0.62),
                Color(red: 0.50, green: 0.62, blue: 0.68)
            ]
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
        VStack(alignment: .leading, spacing: 0) {
            // Stone gradient header (matching StoneFlowRow style)
            stoneHeader

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(stone.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.7))

                    Text(stone.timeRangeString)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    if let date = stone.date {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.5))
                        Text(formatDate(date))
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    if stone.isRecurring, let recurrence = stone.recurrenceType {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.5))
                        Image(systemName: "repeat")
                            .font(.system(size: 11))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Text(recurrence)
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
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
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }

    /// Stone gradient header with texture pattern
    private var stoneHeader: some View {
        ZStack(alignment: .topLeading) {
            // Gradient background simulating stone/rock texture
            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.30, blue: 0.32),
                    Color(red: 0.38, green: 0.40, blue: 0.42),
                    Color(red: 0.45, green: 0.47, blue: 0.50)
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
                // Stone texture pattern
                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(0.03))
                            .frame(width: CGFloat(20 + i * 12), height: CGFloat(20 + i * 12))
                            .offset(
                                x: CGFloat(i * 35 - 40),
                                y: CGFloat(i * 6 - 10)
                            )
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

            // STONE badge - glassy style
            HStack(spacing: 6) {
                Image(systemName: stone.isRecurring ? "repeat" : "calendar")
                    .font(.system(size: 10, weight: .semibold))
                Text(stone.isRecurring ? "RECURRING" : "EVENT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(red: 0.5, green: 0.52, blue: 0.55).opacity(0.35))
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
            .padding(10)
        }
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

// MARK: - Pending Log Row

struct PendingLogRow: View {
    let log: AgentService.PendingTouchLog

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Log icon with green accent circle
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let title = log.projectTitle {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                HStack(spacing: 8) {
                    Text(formattedDuration)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    if let note = log.note, !note.isEmpty {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.5))
                        Text(note)
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
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

// MARK: - Project Wave Shape

/// Wave shape for decorative project headers
struct ProjectWaveShape: Shape {
    let offset: CGFloat
    let amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2

        path.move(to: CGPoint(x: 0, y: midY + offset))

        for x in stride(from: 0, through: width, by: 5) {
            let relativeX = x / width
            let y = midY + offset + sin(relativeX * .pi * 3) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

// MARK: - Sheet Item Helpers

/// Identifiable wrapper for stone sheet presentation
private struct StoneSheetItem: Identifiable {
    let index: Int
    var id: Int { index }
}

/// Identifiable wrapper for project sheet presentation
private struct ProjectSheetItem: Identifiable {
    let index: Int
    var id: Int { index }
}

/// Identifiable wrapper for log sheet presentation
private struct LogSheetItem: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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
