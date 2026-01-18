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
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Projects")
                                .font(DesignSystem.Typography.title)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)

                            Text("PLAN")
                                .font(DesignSystem.Typography.captionBold)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .tracking(1.5)
                        }

                        Spacer()

                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(DesignSystem.Colors.cardBackground)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    if projects.isEmpty {
                        emptyState
                    } else {
                        projectListContent
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
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

    private var projectListContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            if !activeProjects.isEmpty {
                projectSection(title: "ACTIVE", projects: activeProjects)
            }

            if !archivedProjects.isEmpty {
                projectSection(title: "ARCHIVED", projects: archivedProjects)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func projectSection(title: String, projects: [Project]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .sectionHeader()

            ForEach(projects) { project in
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Projects", systemImage: "folder")
        } description: {
            Text("Projects are ongoing work you want to touch.\nAdd a project to start tracking your effort.")
        } actions: {
            Button("Add Project") {
                showingAddSheet = true
            }
        }
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

    private var hoursToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayLogs = project.touchLogs.filter { calendar.startOfDay(for: $0.timestamp) == today }
        let totalMinutes = todayLogs.reduce(0) { $0 + $1.durationMinutes }
        return totalMinutes / 60
    }

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

    private var completedHoursValue: Int {
        project.completedHours
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Top row: Title and hours badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let phase = phaseName {
                        Text(phase)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                if hoursToday > 0 {
                    Text("\(hoursToday) hr\(hoursToday == 1 ? "" : "s") today")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .strokeBorder(DesignSystem.Colors.accent.opacity(0.4), lineWidth: 1)
                        )
                }
            }

            Spacer()

            // Bottom row: Progress bar and hours
            HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.Colors.cardBackgroundLight)
                            .frame(height: 8)

                        // Progress fill
                        if project.totalPlannedMinutes > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.accent)
                                .frame(width: geometry.size.width * project.progress, height: 8)
                        } else if completedHoursValue > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.accent)
                                .frame(width: 20, height: 8)
                        }
                    }
                }
                .frame(height: 8)

                // Chevron and hours
                HStack(spacing: 8) {
                    if project.totalPlannedMinutes > 0 {
                        Text("\(completedHoursValue) / \(totalHours)h")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    } else if completedHoursValue > 0 {
                        Text("\(completedHoursValue)h")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(minHeight: 120)
        .cardStyle()
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
