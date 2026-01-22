import SwiftUI
import SwiftData

/// Detail view for strategic projects with phases and sessions.
/// Supports both manual editing and AI-assisted plan refinement.
struct StrategicProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var prefs: UserPreferences { UserPreferences.shared }

    @Bindable var project: Project

    @State private var showingEditSheet = false
    @State private var showingRefinementChat = false
    @State private var showingDocumentPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var editMode: EditMode = .inactive
    @State private var expandedPhases: Set<String> = []

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header
                headerView
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.sm)

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        // Project title with archetype badge
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(project.title)
                                .font(DesignSystem.Typography.statMedium)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)

                            // Archetype badge inline
                            if let archetype = project.archetype {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: archetype.icon)
                                        .font(.system(size: 12))
                                    Text(archetype.displayName.uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .tracking(0.5)
                                }
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                                .background(DesignSystem.Colors.accent.opacity(0.15))
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.sm)

                        // Context card (if available)
                        if let context = project.planningContext, !context.isEmpty {
                            contextCard(context)
                        }

                        // Deadline card (prominent if exists)
                        if project.deadline != nil {
                            deadlineCard
                        }

                        // Progress section
                        progressCard

                        // Phase list (for phase mode) or milestone list (for milestone mode)
                        if project.isPhaseMode {
                            phasesCard
                        } else {
                            milestonesCard
                        }

                        // Attached documents
                        if !project.documents.isEmpty {
                            documentsCard
                        }

                        // Actions
                        actionsCard
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
        }
        .navigationBarHidden(true)
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $showingEditSheet) {
            ProjectFormView(mode: .edit(project)) { _ in }
        }
        .sheet(isPresented: $showingRefinementChat) {
            PlanRefinementChatView(project: project)
        }
        .confirmationDialog(
            "Delete Project",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(project.title)\"? This will delete all phases, sessions, documents, and touch history. This action cannot be undone.")
        }
    }

    private func deleteProject() {
        modelContext.delete(project)
        dismiss()
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            }

            Spacer()

            // Active toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    project.isActive.toggle()
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Circle()
                        .fill(project.isActive ? DesignSystem.Colors.success : DesignSystem.Colors.textTertiary)
                        .frame(width: 8, height: 8)
                    Text(project.isActive ? "Active" : "Paused")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(project.isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.cardBackground)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                )
            }

            // Menu button
            Menu {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit Details", systemImage: "pencil")
                }

                Button {
                    showingRefinementChat = true
                } label: {
                    Label("Refine Plan with AI", systemImage: "sparkles")
                }

                Divider()

                Button {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                } label: {
                    Label(
                        editMode.isEditing ? "Done Editing" : "Edit Sessions",
                        systemImage: editMode.isEditing ? "checkmark" : "slider.horizontal.3"
                    )
                }

                Divider()

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Project", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Context Card

    private func contextCard(_ context: String) -> some View {
        Text(context)
            .font(DesignSystem.Typography.body)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Deadline Card

    private var deadlineCard: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: deadlineIcon)
                .font(.system(size: 22))
                .foregroundStyle(deadlineColor)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                        .fill(DesignSystem.Colors.background)
                )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("DEADLINE")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1)

                if let deadline = project.deadline {
                    Text(formattedDeadline(deadline))
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
            }

            Spacer()

            if let deadline = project.deadline {
                Text(daysUntilDeadline(deadline))
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(deadlineColor)
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

    private var deadlineIcon: String {
        switch project.feasibilityStatus {
        case .overdue, .impossible: return "exclamationmark.triangle.fill"
        case .atRisk, .tight: return "clock.fill"
        default: return "calendar"
        }
    }


    private func formattedDeadline(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func daysUntilDeadline(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 {
            return "\(abs(days)) days overdue"
        } else if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "1 day left"
        } else {
            return "\(days) days left"
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text("Project Vitality")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
            }

            // Time invested vs planned
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
                Text("\(project.completedHours)")
                    .font(DesignSystem.Typography.statLarge)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("/ \(project.totalPlannedHours) hrs")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Spacer()

                // Remaining time
                if project.remainingHours > 0 {
                    Text("\(project.remainingHours)h left")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                } else {
                    Text("Complete!")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.success)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                        .fill(DesignSystem.Colors.textTertiary.opacity(0.2))
                        .frame(height: DesignSystem.Spacing.sm)

                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: max(geometry.size.width * project.progress, 0), height: DesignSystem.Spacing.sm)
                }
            }
            .frame(height: DesignSystem.Spacing.sm)
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Phases Card (Phase Mode)

    private var phasesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text("Phases")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(project.sortedPhases.enumerated()), id: \.element.id) { index, phase in
                    PhaseProgressRow(
                        phase: phase,
                        isActive: phase.id == project.activePhase?.id,
                        isExpanded: expandedPhases.contains(phase.id.uuidString),
                        isLast: index == project.sortedPhases.count - 1,
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedPhases.contains(phase.id.uuidString) {
                                    expandedPhases.remove(phase.id.uuidString)
                                } else {
                                    expandedPhases.insert(phase.id.uuidString)
                                }
                            }
                        }
                    )
                }
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

    // MARK: - Milestones Card (Milestone Mode)

    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "checklist")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text("Milestones")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()

                Text("\(project.completedMilestoneCount)/\(project.totalMilestoneCount)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(project.sortedMilestones) { milestone in
                    MilestoneRow(milestone: milestone)
                }
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

    // MARK: - Documents Card

    private var documentsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text("Documents")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
            }

            ForEach(project.documents) { document in
                DocumentAttachmentRow(document: document) {
                    modelContext.delete(document)
                }
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

    // MARK: - Actions Card

    private var actionsCard: some View {
        Button {
            logTouch()
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 20))
                Text("Log Touch Now")
                    .font(DesignSystem.Typography.headline)
            }
            .foregroundStyle(DesignSystem.Colors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg + 2)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                    .fill(DesignSystem.Colors.accent)
            )
        }
    }

    // MARK: - Helpers

    private var deadlineColor: Color {
        switch project.feasibilityStatus {
        case .noDeadline, .healthy: return DesignSystem.Colors.textSecondary
        case .tight: return DesignSystem.Colors.warning
        case .atRisk: return DesignSystem.Colors.warning
        case .impossible, .overdue: return DesignSystem.Colors.error
        }
    }

    private func logTouch() {
        let touch = TouchLog(project: project)
        modelContext.insert(touch)
    }
}

// MARK: - Phase Progress Row

/// A row showing phase with time budget progress (no individual sessions)
struct PhaseProgressRow: View {
    @Bindable var phase: ProjectPhase
    let isActive: Bool
    let isExpanded: Bool
    let isLast: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Phase header row
            Button(action: onToggleExpand) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Active indicator
                    Circle()
                        .fill(isActive ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary.opacity(0.3))
                        .frame(width: 8, height: 8)

                    // Phase title
                    Text(phase.title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(isActive ? .semibold : .regular)
                        .foregroundStyle(isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)

                    Spacer()

                    // Time progress
                    Text(phase.progressString)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(phase.isComplete ? DesignSystem.Colors.success : DesignSystem.Colors.textTertiary)

                    // Phase type badge
                    Text(phase.phaseType.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(isActive ? DesignSystem.Colors.accent.opacity(0.15) : DesignSystem.Colors.textTertiary.opacity(0.1))
                        .foregroundStyle(isActive ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                        .clipShape(Capsule())

                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Mental rule if available
                    if let rule = phase.mentalRule {
                        Text("\"\(rule)\"")
                            .font(DesignSystem.Typography.caption)
                            .italic()
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .padding(.leading, DesignSystem.Spacing.xl)
                    }

                    // Progress bar
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ProgressView(value: phase.progress)
                            .tint(phase.isComplete ? DesignSystem.Colors.success : DesignSystem.Colors.accent)

                        if phase.isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignSystem.Colors.success)
                                .font(.caption)
                        }
                    }
                    .padding(.leading, DesignSystem.Spacing.xl)
                    .padding(.trailing, DesignSystem.Spacing.md)

                    // Time budget info
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        Label("\(phase.minutesInvested / 60)h invested", systemImage: "clock")
                        Label("\(phase.remainingMinutes / 60)h remaining", systemImage: "hourglass")
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.leading, DesignSystem.Spacing.xl)
                }
                .padding(.bottom, DesignSystem.Spacing.sm)
            }

            // Divider (except for last item)
            if !isLast {
                Rectangle()
                    .fill(DesignSystem.Colors.textTertiary.opacity(0.2))
                    .frame(height: 1)
                    .padding(.leading, DesignSystem.Spacing.xl)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StrategicProjectDetailView(
            project: Project(title: "ML Research Paper", archetype: .lab, totalPlannedMinutes: 2400)
        )
    }
    .modelContainer(for: [Project.self, ProjectPhase.self, Milestone.self, TouchLog.self, ProjectDocument.self], inMemory: true)
}
