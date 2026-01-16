import SwiftUI
import SwiftData

// MARK: - Flow Edit Mode View

/// Edit mode for rearranging flow items.
/// Shows available projects at the top that can be dragged to replace items in the flow below.
struct FlowEditModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var dayPlan: DayPlan
    let allProjects: [Project]
    let onDismiss: () -> Void

    @State private var draggedProject: Project?
    @State private var highlightedSessionId: UUID?
    @State private var hasChanges = false

    private let cardBackground = Color(uiColor: UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1.0))
    private let screenBackground = Color(uiColor: UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1.0))

    /// Projects currently in the scheduled flow
    private var scheduledProjectIds: Set<UUID> {
        Set(dayPlan.scheduledSessions.compactMap { $0.project?.id })
    }

    /// Projects available for adding (not already in flow)
    private var availableProjects: [Project] {
        allProjects.filter { project in
            project.isActive && !scheduledProjectIds.contains(project.id)
        }
    }

    /// Sorted sessions for display
    private var sortedSessions: [ScheduledSession] {
        dayPlan.sortedSessions.filter { $0.status == .pending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                screenBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header instructions
                    instructionsHeader
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Available projects section (top)
                    if !availableProjects.isEmpty {
                        availableProjectsSection
                    }

                    Divider()
                        .background(Color(.systemGray4))
                        .padding(.vertical, 16)

                    // Current flow section (bottom) - drop targets
                    currentFlowSection
                }
            }
            .navigationTitle("Edit Flow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.teal)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Instructions Header

    private var instructionsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.teal)
                Text("Drag projects to swap or add to your flow")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    // MARK: - Available Projects Section

    private var availableProjectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AVAILABLE PROJECTS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color(.systemGray2))
                .tracking(2)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availableProjects) { project in
                        DraggableProjectCard(
                            project: project,
                            isDragging: draggedProject?.id == project.id
                        )
                        .onDrag {
                            draggedProject = project
                            return NSItemProvider(object: project.id.uuidString as NSString)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Current Flow Section

    private var currentFlowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TODAY'S FLOW")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.systemGray2))
                    .tracking(2)

                Spacer()

                if sortedSessions.count > 0 {
                    Text("\(sortedSessions.count) sessions")
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray3))
                }
            }
            .padding(.horizontal)

            if sortedSessions.isEmpty {
                emptyFlowState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(sortedSessions) { session in
                            FlowSessionDropTarget(
                                session: session,
                                isHighlighted: highlightedSessionId == session.id,
                                allProjects: allProjects,
                                onSwap: { newProject in
                                    swapSessionProject(session: session, newProject: newProject)
                                },
                                onDelete: {
                                    deleteSession(session)
                                },
                                onDragEnter: {
                                    highlightedSessionId = session.id
                                },
                                onDragExit: {
                                    if highlightedSessionId == session.id {
                                        highlightedSessionId = nil
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var emptyFlowState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No sessions in flow")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Drag projects from above to add them")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    private func swapSessionProject(session: ScheduledSession, newProject: Project) {
        // Update the session's project
        session.project = newProject
        hasChanges = true

        // Clear highlight
        highlightedSessionId = nil
        draggedProject = nil

        // Haptic feedback
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }

    private func deleteSession(_ session: ScheduledSession) {
        modelContext.delete(session)
        hasChanges = true

        // Haptic feedback
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
}

// MARK: - Draggable Project Card

/// A compact card representing a project that can be dragged
struct DraggableProjectCard: View {
    let project: Project
    let isDragging: Bool

    private let cardBackground = Color(uiColor: UIColor(red: 0.22, green: 0.24, blue: 0.26, alpha: 1.0))

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let phase = project.currentPhase {
                Text(phase)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 120, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.teal.opacity(0.4), lineWidth: 1.5)
                )
        )
        .opacity(isDragging ? 0.5 : 1.0)
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }
}

// MARK: - Flow Session Drop Target

/// A session slot in the flow that can receive dropped projects
struct FlowSessionDropTarget: View {
    let session: ScheduledSession
    let isHighlighted: Bool
    let allProjects: [Project]
    let onSwap: (Project) -> Void
    let onDelete: () -> Void
    let onDragEnter: () -> Void
    let onDragExit: () -> Void

    @State private var showDeleteConfirm = false
    @State private var isTargeted = false

    private let cardBackground = Color(uiColor: UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1.0))

    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(session.timeRangeString)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text("\(session.durationMinutes)m")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 90, alignment: .leading)

            // Project info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if let phase = session.project?.currentPhase {
                    Text(phase)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Delete button
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(.systemGray3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isHighlighted || isTargeted ? Color.teal : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .scaleEffect(isHighlighted || isTargeted ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: isTargeted) { _, newValue in
            if newValue {
                onDragEnter()
            } else {
                onDragExit()
            }
        }
        .confirmationDialog("Remove from flow?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the session from today's schedule.")
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadObject(ofClass: NSString.self) { item, error in
            DispatchQueue.main.async {
                if let uuidString = item as? String,
                   let uuid = UUID(uuidString: uuidString) {
                    // Find the project by ID
                    if let project = allProjects.first(where: { $0.id == uuid }) {
                        onSwap(project)
                    }
                }
            }
        }

        return true
    }
}

// MARK: - Preview

#Preview {
    FlowEditModeView(
        dayPlan: DayPlan(),
        allProjects: [],
        onDismiss: {}
    )
    .modelContainer(for: [DayPlan.self, Project.self, ScheduledSession.self], inMemory: true)
}
