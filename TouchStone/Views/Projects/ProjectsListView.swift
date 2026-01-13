import SwiftUI
import SwiftData

struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    @State private var showingAddSheet = false

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
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NewProjectChoiceView()
            }
        }
    }

    private var projectList: some View {
        List {
            Section {
                ForEach(projects.filter { $0.isActive }) { project in
                    ProjectRow(project: project)
                }
                .onDelete { indexSet in
                    deleteProjects(at: indexSet, from: projects.filter { $0.isActive })
                }
            } header: {
                if !projects.filter({ $0.isActive }).isEmpty {
                    Text("Active")
                }
            }

            Section {
                ForEach(projects.filter { !$0.isActive }) { project in
                    ProjectRow(project: project)
                }
                .onDelete { indexSet in
                    deleteProjects(at: indexSet, from: projects.filter { !$0.isActive })
                }
            } header: {
                if !projects.filter({ !$0.isActive }).isEmpty {
                    Text("Archived")
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

struct ProjectRow: View {
    @Bindable var project: Project

    var body: some View {
        NavigationLink {
            ProjectDetailView(project: project)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(project.title)
                        .fontWeight(.medium)

                    if project.hasStrategicPlan, let archetype = project.archetype {
                        Text(archetype.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if project.touchCountToday > 0 {
                        Text("Today: \(project.touchCountToday)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 8) {
                    // Phase name
                    if project.hasStrategicPlan {
                        if let phase = project.activePhase {
                            Text(phase.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let phase = project.currentPhase {
                        Text(phase)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Hours progress
                    if project.totalPlannedMinutes > 0 {
                        Text(project.hoursString)
                            .font(.caption)
                            .foregroundStyle(Color.purple)
                    } else if project.completedHours > 0 {
                        Text("\(project.completedHours) hrs")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Hours-based progress bar
                if project.totalPlannedMinutes > 0 {
                    ProgressView(value: project.progress)
                        .tint(.purple)
                }
            }
        }
    }
}

#Preview {
    ProjectsListView()
        .modelContainer(for: [Project.self, ProjectPhase.self, PlannedSession.self, TouchLog.self], inMemory: true)
}
