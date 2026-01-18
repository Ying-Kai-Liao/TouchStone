import SwiftUI
import SwiftData

struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    @State private var showingAddSheet = false
    @State private var projectToDelete: Project?
    @State private var showDeleteAlert = false
    @State private var selectedProject: Project?

    private var activeProjects: [Project] {
        projects.filter { $0.isActive }
    }

    private var archivedProjects: [Project] {
        projects.filter { !$0.isActive }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom header
                    headerView
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // Content
                    if projects.isEmpty {
                        emptyState
                    } else {
                        projectList
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSheet) {
                NewProjectChoiceView()
            }
            .alert("Delete Project", isPresented: $showDeleteAlert, presenting: projectToDelete) { project in
                Button("Cancel", role: .cancel) {
                    projectToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteProject(project)
                }
            } message: { project in
                Text("Delete \"\(project.title)\"? This cannot be undone.")
            }
            .navigationDestination(item: $selectedProject) { project in
                ProjectDetailView(project: project)
            }
        }
    }

    private func deleteProject(_ project: Project) {
        modelContext.delete(project)
        projectToDelete = nil
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center) {
            Text("Projects")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
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

    // MARK: - Project List

    private var projectList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(activeProjects) { project in
                    SwipeToDeleteRow(
                        onDelete: {
                            projectToDelete = project
                            showDeleteAlert = true
                        }
                    ) {
                        ProjectCard(project: project) {
                            selectedProject = project
                        }
                    }
                }

                if !archivedProjects.isEmpty {
                    // Archived section with header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ARCHIVED")
                            .font(DesignSystem.Typography.captionBold)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .tracking(1.5)
                            .padding(.leading, 4)
                            .padding(.top, 8)

                        ForEach(archivedProjects) { project in
                            SwipeToDeleteRow(
                                onDelete: {
                                    projectToDelete = project
                                    showDeleteAlert = true
                                }
                            ) {
                                ProjectCard(project: project) {
                                    selectedProject = project
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("No Projects")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text("Projects are ongoing work you want to touch.\nAdd a project to start tracking your effort.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                showingAddSheet = true
            } label: {
                Text("Add Project")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.accent.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.background)
    }

    private func deleteProjects(at offsets: IndexSet, from list: [Project]) {
        for index in offsets {
            modelContext.delete(list[index])
        }
    }
}

struct ProjectCard: View {
    @Bindable var project: Project
    let onTap: () -> Void

    private var phaseName: String? {
        if project.hasStrategicPlan {
            return project.activePhase?.title
        } else {
            return project.currentPhase
        }
    }

    private var totalHours: Int {
        project.totalPlannedMinutes / 60
    }

    private var completedHours: Int {
        project.completedHours
    }

    /// Category label based on project type/phase
    private var categoryLabel: String {
        if project.hasStrategicPlan {
            if let phase = project.activePhase {
                // Map phase mental rule to category
                switch phase.mentalRule {
                case "divergent": return "EXPLORATION"
                case "convergent": return "DEEP FOCUS"
                case "iterative": return "BUILDING FLOW"
                default: return "ACTIVE GROWTH"
                }
            }
            return "ACTIVE GROWTH"
        }
        return "BUILDING FLOW"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top section: Title and phase
            VStack(alignment: .leading, spacing: 6) {
                Text(project.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let phase = phaseName {
                    Text(phase)
                        .font(.system(size: 15))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }

            Spacer(minLength: 24)

            // Bottom section: Category label, hours, and progress bar
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(categoryLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .tracking(1)

                    Spacer()

                    if totalHours > 0 {
                        Text("\(completedHours) / \(totalHours) hrs")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.accent)
                    } else if completedHours > 0 {
                        Text("\(completedHours) hrs")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }

                // Progress bar - full width
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.Colors.textTertiary.opacity(0.2))
                            .frame(height: 6)

                        // Progress fill
                        if project.totalPlannedMinutes > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.accent.opacity(0.8))
                                .frame(width: max(geometry.size.width * project.progress, 0), height: 6)
                        } else if completedHours > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.accent.opacity(0.8))
                                .frame(width: 20, height: 6)
                        }
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(24)
        .frame(minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// Keep the old ProjectRow for backwards compatibility if needed elsewhere
struct ProjectRow: View {
    @Bindable var project: Project
    var onTap: () -> Void = {}

    var body: some View {
        ProjectCard(project: project, onTap: onTap)
    }
}

#Preview {
    ProjectsListView()
        .modelContainer(for: [Project.self, ProjectPhase.self, PlannedSession.self, TouchLog.self], inMemory: true)
}
