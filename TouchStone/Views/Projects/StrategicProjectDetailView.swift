import SwiftUI
import SwiftData

/// Detail view for strategic projects with phases and sessions.
/// Supports both manual editing and AI-assisted plan refinement.
struct StrategicProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var prefs = UserPreferences.shared

    @Bindable var project: Project

    @State private var showingEditSheet = false
    @State private var showingRefinementChat = false
    @State private var showingDocumentPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedSession: PlannedSession?
    @State private var expandedPhases: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Project header with archetype and context
                projectHeaderCard

                // Deadline card (prominent if exists)
                if project.deadline != nil {
                    deadlineCard
                }

                // Progress section
                progressCard

                // Phase list with indicator
                phasesCard

                // Attached documents
                if !project.documents.isEmpty {
                    documentsCard
                }

                // Actions
                actionsCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $showingEditSheet) {
            ProjectFormView(mode: .edit(project)) { _ in }
        }
        .sheet(isPresented: $showingRefinementChat) {
            PlanRefinementChatView(project: project)
        }
        .sheet(item: $selectedSession) { session in
            SessionEditorSheet(session: session)
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

    // MARK: - Header Card

    private var projectHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Archetype badge
            if let archetype = project.archetype {
                HStack {
                    Image(systemName: archetype.icon)
                    Text(archetype.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(prefs.accentColor.opacity(0.15))
                .foregroundStyle(prefs.accentColor)
                .clipShape(Capsule())
            }

            // Description/context if available
            if let context = project.planningContext, !context.isEmpty {
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Deadline Card

    private var deadlineCard: some View {
        HStack(spacing: 12) {
            Image(systemName: deadlineIcon)
                .font(.title2)
                .foregroundStyle(deadlineColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Deadline")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let deadline = project.deadline {
                    Text(formattedDeadline(deadline))
                        .font(.headline)
                        .foregroundStyle(deadlineColor)
                }
            }

            Spacer()

            if let deadline = project.deadline {
                Text(daysUntilDeadline(deadline))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(deadlineColor)
            }
        }
        .padding()
        .background(deadlineBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var deadlineIcon: String {
        switch project.feasibilityStatus {
        case .overdue, .impossible: return "exclamationmark.triangle.fill"
        case .atRisk, .tight: return "clock.fill"
        default: return "calendar"
        }
    }

    private var deadlineBackgroundColor: Color {
        switch project.feasibilityStatus {
        case .overdue, .impossible: return Color.red.opacity(0.1)
        case .atRisk: return Color.orange.opacity(0.1)
        case .tight: return Color.yellow.opacity(0.1)
        default: return Color(.secondarySystemGroupedBackground)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.secondary)
                Text("Progress")
                    .font(.headline)
                Spacer()
            }

            // Time invested vs planned
            HStack(alignment: .firstTextBaseline) {
                Text("\(project.completedHours)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(prefs.accentColor)

                Text("/ \(project.totalPlannedHours) hrs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Remaining time
                if project.remainingHours > 0 {
                    Text("\(project.remainingHours)h left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Complete!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // Progress bar
            ProgressView(value: project.progress)
                .tint(prefs.accentColor)
                .scaleEffect(y: 1.5)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Phases Card

    private var phasesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundStyle(.secondary)
                Text("Phases")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(project.sortedPhases.enumerated()), id: \.element.id) { index, phase in
                    CollapsiblePhaseRow(
                        phase: phase,
                        isActive: phase.id == project.activePhase?.id,
                        isExpanded: expandedPhases.contains(phase.id.uuidString),
                        isLast: index == project.sortedPhases.count - 1,
                        isEditing: editMode.isEditing,
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedPhases.contains(phase.id.uuidString) {
                                    expandedPhases.remove(phase.id.uuidString)
                                } else {
                                    expandedPhases.insert(phase.id.uuidString)
                                }
                            }
                        },
                        onSessionTap: { session in
                            selectedSession = session
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Documents Card

    private var documentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)
                Text("Documents")
                    .font(.headline)
                Spacer()
            }

            ForEach(project.documents) { document in
                DocumentAttachmentRow(document: document) {
                    modelContext.delete(document)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: 12) {
            Button {
                logTouch()
            } label: {
                HStack {
                    Image(systemName: "hand.tap.fill")
                    Text("Log Touch Now")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(prefs.accentColor)

            HStack {
                Text("Active")
                    .font(.subheadline)
                Spacer()
                Toggle("", isOn: $project.isActive)
                    .labelsHidden()
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var deadlineColor: Color {
        switch project.feasibilityStatus {
        case .noDeadline, .healthy: return .secondary
        case .tight: return .yellow
        case .atRisk: return .orange
        case .impossible, .overdue: return .red
        }
    }

    private func logTouch() {
        let touch = TouchLog(project: project)
        modelContext.insert(touch)
    }
}

// MARK: - Collapsible Phase Row

struct CollapsiblePhaseRow: View {
    @Bindable var phase: ProjectPhase
    let isActive: Bool
    let isExpanded: Bool
    let isLast: Bool
    let isEditing: Bool
    let onToggleExpand: () -> Void
    let onSessionTap: (PlannedSession) -> Void

    private var completedCount: Int {
        phase.sortedSessions.filter { $0.status == .completed }.count
    }

    private var totalCount: Int {
        phase.sortedSessions.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Phase header row
            Button(action: onToggleExpand) {
                HStack(spacing: 12) {
                    // Active indicator
                    Circle()
                        .fill(isActive ? UserPreferences.shared.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)

                    // Phase title
                    Text(phase.title)
                        .font(.subheadline)
                        .fontWeight(isActive ? .semibold : .regular)
                        .foregroundStyle(isActive ? .primary : .secondary)

                    Spacer()

                    // Session count
                    Text("\(completedCount)/\(totalCount)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    // Phase type badge
                    Text(phase.phaseType.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isActive ? UserPreferences.shared.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                        .foregroundStyle(isActive ? UserPreferences.shared.accentColor : .secondary)
                        .clipShape(Capsule())

                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Expanded sessions
            if isExpanded {
                VStack(spacing: 6) {
                    // Mental rule if available
                    if let rule = phase.mentalRule {
                        Text("\"\(rule)\"")
                            .font(.caption)
                            .italic()
                            .foregroundStyle(UserPreferences.shared.accentColor)
                            .padding(.leading, 20)
                            .padding(.bottom, 4)
                    }

                    ForEach(phase.sortedSessions) { session in
                        MinimalSessionRow(
                            session: session,
                            isEditing: isEditing,
                            onTap: { onSessionTap(session) }
                        )
                    }
                }
                .padding(.bottom, 8)
            }

            // Divider (except for last item)
            if !isLast {
                Divider()
                    .padding(.leading, 20)
            }
        }
    }
}

// MARK: - Minimal Session Row

struct MinimalSessionRow: View {
    @Bindable var session: PlannedSession
    let isEditing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Status indicator
                Image(systemName: session.status.icon)
                    .font(.caption2)
                    .foregroundStyle(colorForStatus)
                    .frame(width: 16)

                // Session title
                Text(session.title)
                    .font(.caption)
                    .foregroundStyle(session.status == .skipped ? .secondary : .primary)
                    .strikethrough(session.status == .skipped)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.leading, 20)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .opacity(session.status == .skipped ? 0.6 : 1.0)
    }

    private var colorForStatus: Color {
        switch session.status {
        case .planned: return .secondary
        case .completed: return .green
        case .skipped: return .orange
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
    .modelContainer(for: [Project.self, ProjectPhase.self, PlannedSession.self, TouchLog.self, ProjectDocument.self], inMemory: true)
}
