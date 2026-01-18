import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project

    @State private var showingEditSheet = false
    @State private var showingLogSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingMenu = false

    // MARK: - Computed Properties

    private var totalHours: Int {
        project.totalPlannedMinutes / 60
    }

    private var completedHours: Int {
        project.completedHours
    }

    private var remainingHours: Int {
        max(0, totalHours - completedHours)
    }

    private var progressPercent: Int {
        Int(project.progress * 100)
    }

    private var daysUntilDeadline: Int? {
        guard let deadline = project.deadline else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: deadline)).day
        return days
    }

    var body: some View {
        // Route to strategic view for projects with phases
        if project.hasStrategicPlan {
            StrategicProjectDetailView(project: project)
        } else {
            simpleProjectView
        }
    }

    // MARK: - Simple Project View (no strategic plan)

    private var simpleProjectView: some View {
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
                        // Project title
                        Text(project.title)
                            .font(DesignSystem.Typography.statMedium)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding(.top, DesignSystem.Spacing.sm)

                        // Phase card
                        if let phase = project.currentPhase, !phase.isEmpty {
                            phaseCard(phase)
                        }

                        // Deadline card
                        if let deadline = project.deadline {
                            deadlineCard(deadline)
                        }

                        // Project vitality card
                        vitalityCard

                        // Log Touch button
                        logTouchButton

                        // Recent touches section
                        if !project.touchLogs.isEmpty {
                            recentTouchesSection
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditSheet) {
            ProjectFormView(mode: .edit(project)) { _ in }
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
            Text("Are you sure you want to delete \"\(project.title)\"? This will also delete all associated touches and data. This action cannot be undone.")
        }
        .confirmationDialog("Options", isPresented: $showingMenu) {
            Button("Edit Details") {
                showingEditSheet = true
            }
            Button("Delete Project", role: .destructive) {
                showingDeleteConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        }
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

            // Menu button
            Button {
                showingMenu = true
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

    // MARK: - Phase Card

    private func phaseCard(_ phase: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "flask")
                .font(.system(size: 18))
                .foregroundStyle(DesignSystem.Colors.accent)

            Text(phase.uppercased())
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.accent)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
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

    private func deadlineCard(_ deadline: Date) -> some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Calendar icon
            Image(systemName: "calendar")
                .font(.system(size: 22))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
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

                Text(formattedDeadline(deadline))
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }

            Spacer()

            if let days = daysUntilDeadline {
                Text(days >= 0 ? "\(days) days left" : "Overdue")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(days >= 0 ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.error)
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

    // MARK: - Vitality Card

    private var vitalityCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header row
            HStack {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("Project Vitality")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                Spacer()

                if totalHours > 0 {
                    Text("\(progressPercent)% Complete")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }

            // Hours display
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
                Text("\(completedHours)")
                    .font(DesignSystem.Typography.statLarge)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                if totalHours > 0 {
                    Text("/ \(totalHours) hrs")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                } else {
                    Text("hrs")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                        .fill(DesignSystem.Colors.textTertiary.opacity(0.2))
                        .frame(height: DesignSystem.Spacing.sm)

                    if totalHours > 0 {
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: max(geometry.size.width * project.progress, 0), height: DesignSystem.Spacing.sm)
                    } else if completedHours > 0 {
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: 30, height: DesignSystem.Spacing.sm)
                    }
                }
            }
            .frame(height: DesignSystem.Spacing.sm)

            // Bottom row
            HStack {
                Text("ONGOING PROJECT")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1)

                Spacer()

                if totalHours > 0 {
                    Text("\(remainingHours)h remaining")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
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

    // MARK: - Log Touch Button

    private var logTouchButton: some View {
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

    // MARK: - Recent Touches Section

    private var recentTouchesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                Text("Recent Touches")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.top, DesignSystem.Spacing.sm)

            ForEach(project.touchLogs.sorted { $0.timestamp > $1.timestamp }.prefix(5)) { touch in
                TouchLogRow(touchLog: touch)
            }
        }
    }

    private func deleteProject() {
        modelContext.delete(project)
        dismiss()
    }

    private var deadlineColor: Color {
        switch project.feasibilityStatus {
        case .noDeadline, .healthy: return DesignSystem.Colors.textSecondary
        case .tight: return DesignSystem.Colors.warning
        case .atRisk: return DesignSystem.Colors.warning
        case .impossible, .overdue: return DesignSystem.Colors.error
        }
    }

    private func formattedDeadline(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func deadlineText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: date)

        switch project.feasibilityStatus {
        case .overdue: return "Past deadline: \(dateStr)"
        case .impossible: return "Deadline: \(dateStr) (tight)"
        case .atRisk, .tight: return "Deadline: \(dateStr) (soon)"
        default: return "Deadline: \(dateStr)"
        }
    }

    private func formattedTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }

    private func logTouch() {
        let touch = TouchLog(project: project)
        modelContext.insert(touch)
    }
}

struct TouchLogRow: View {
    let touchLog: TouchLog

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(touchLog.formattedDate)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                if let note = touchLog.note, !note.isEmpty {
                    Text(note)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(touchLog.formattedDuration)
                .font(DesignSystem.Typography.callout)
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: Project(title: "Q4 Strategy", currentPhase: "Discovery"))
    }
    .modelContainer(for: [Project.self, TouchLog.self], inMemory: true)
}
