import SwiftUI
import SwiftData

/// Detail view for strategic projects with phases and sessions.
/// Supports both manual editing and AI-assisted plan refinement.
struct StrategicProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project

    @State private var showingEditSheet = false
    @State private var showingRefinementChat = false
    @State private var showingDocumentPicker = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedSession: PlannedSession?

    var body: some View {
        List {
            // Project header section
            projectHeaderSection

            // Time invested - the core metric
            progressSection

            // Current phase with mental rule
            currentPhaseSection

            // Phases with sessions
            ForEach(project.sortedPhases) { phase in
                PhaseSection(
                    phase: phase,
                    isEditing: editMode.isEditing,
                    onSessionTap: { session in
                        selectedSession = session
                    }
                )
            }

            // Attached documents
            if !project.documents.isEmpty {
                documentsSection
            }

            // Actions section
            actionsSection
        }
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
    }

    // MARK: - Header Section

    private var projectHeaderSection: some View {
        Section {
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
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                }

                // Description/context if available
                if let context = project.planningContext, !context.isEmpty {
                    Text(context)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                // Deadline if set
                if let deadline = project.softDeadline {
                    Label(deadlineText(deadline), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(deadlineColor)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Time invested vs planned - the core metric
                HStack(alignment: .firstTextBaseline) {
                    Text("\(project.completedHours)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.purple)

                    Text("/ \(project.totalPlannedHours) hrs")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                // Progress bar
                ProgressView(value: project.progress)
                    .tint(.purple)
                    .scaleEffect(y: 2)
                    .padding(.vertical, 4)

                // Remaining time
                if project.remainingHours > 0 {
                    Text("\(project.remainingHours) hours remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Goal reached!")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Time Invested")
        }
    }

    // MARK: - Current Phase Section

    @ViewBuilder
    private var currentPhaseSection: some View {
        if let activePhase = project.activePhase {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(activePhase.title)
                            .font(.headline)

                        Spacer()

                        Text(activePhase.phaseType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    if let rule = activePhase.mentalRule {
                        Text("\"\(rule)\"")
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(.purple)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Current Phase")
            }
        }
    }

    // MARK: - Documents Section

    private var documentsSection: some View {
        Section("Attached Documents") {
            ForEach(project.documents) { document in
                DocumentAttachmentRow(document: document) {
                    modelContext.delete(document)
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button {
                logTouch()
            } label: {
                Label("Log Touch Now", systemImage: "hand.tap")
            }

            Toggle("Active", isOn: $project.isActive)
        }
    }

    // MARK: - Helpers

    private var deadlineColor: Color {
        switch project.deadlineStatus {
        case .none, .comfortable: return .secondary
        case .approaching: return .orange
        case .passed: return .red
        }
    }

    private func deadlineText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: date)

        switch project.deadlineStatus {
        case .passed: return "Past target: \(dateStr)"
        case .approaching: return "Target: \(dateStr) (soon)"
        default: return "Target: \(dateStr)"
        }
    }

    private func logTouch() {
        let touch = TouchLog(project: project)
        modelContext.insert(touch)
    }
}

// MARK: - Phase Section

struct PhaseSection: View {
    @Bindable var phase: ProjectPhase
    let isEditing: Bool
    let onSessionTap: (PlannedSession) -> Void

    var body: some View {
        Section {
            ForEach(phase.sortedSessions) { session in
                EditableSessionRow(
                    session: session,
                    isEditing: isEditing,
                    onTap: { onSessionTap(session) }
                )
            }
        } header: {
            phaseHeader
        } footer: {
            phaseFooter
        }
    }

    private var phaseHeader: some View {
        HStack {
            Text(phase.title)
                .fontWeight(.medium)

            Spacer()

            Text(phase.phaseType.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var phaseFooter: some View {
        if let rule = phase.mentalRule {
            Text("Rule: \"\(rule)\"")
                .font(.caption)
                .italic()
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
