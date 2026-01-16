import SwiftUI
import SwiftData

struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    @State private var showingAddSheet = false

    private var activeProjects: [Project] {
        projects.filter { $0.isActive }
    }

    private var archivedProjects: [Project] {
        projects.filter { !$0.isActive }
    }

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    emptyState
                } else {
                    projectList
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NewProjectChoiceView()
            }
        }
    }

    private var projectList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !activeProjects.isEmpty {
                    projectSection(title: "ACTIVE", projects: activeProjects)
                }

                if !archivedProjects.isEmpty {
                    projectSection(title: "ARCHIVED", projects: archivedProjects)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemBackground))
    }

    private func projectSection(title: String, projects: [Project]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(1)
                .padding(.leading, 4)

            ForEach(projects) { project in
                ProjectCard(project: project)
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
        NavigationLink {
            ProjectDetailView(project: project)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Title and hours badge
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if let phase = phaseName {
                            Text(phase)
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        if hoursToday > 0 {
                            Text("\(hoursToday) hr\(hoursToday == 1 ? "" : "s") today")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(UserPreferences.shared.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .strokeBorder(UserPreferences.shared.accentColor.opacity(0.4), lineWidth: 1)
                                )
                        }
                    }
                }

                Spacer()

                // Bottom row: Progress bar and hours
                HStack(alignment: .center, spacing: 12) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 8)

                            // Progress fill
                            if project.totalPlannedMinutes > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(UserPreferences.shared.accentColor)
                                    .frame(width: geometry.size.width * project.progress, height: 8)
                            } else if completedHoursValue > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(UserPreferences.shared.accentColor)
                                    .frame(width: 20, height: 8)
                            }
                        }
                    }
                    .frame(height: 8)

                    // Chevron and hours
                    HStack(spacing: 8) {
                        if project.totalPlannedMinutes > 0 {
                            Text("\(completedHoursValue) / \(totalHours)h")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.5))
                        } else if completedHoursValue > 0 {
                            Text("\(completedHoursValue)h")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.5))
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                }
            }
            .padding(16)
            .frame(minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.1, green: 0.18, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color(red: 0.2, green: 0.35, blue: 0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// Keep the old ProjectRow for backwards compatibility if needed elsewhere
struct ProjectRow: View {
    @Bindable var project: Project

    var body: some View {
        ProjectCard(project: project)
    }
}

#Preview {
    ProjectsListView()
        .modelContainer(for: [Project.self, ProjectPhase.self, PlannedSession.self, TouchLog.self], inMemory: true)
}
