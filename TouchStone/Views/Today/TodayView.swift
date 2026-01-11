import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<StoneEvent> { $0.isActive })
    private var allStones: [StoneEvent]

    @Query(filter: #Predicate<Project> { $0.isActive }, sort: \Project.createdAt, order: .reverse)
    private var activeProjects: [Project]

    @State private var dayState = DayState()
    @State private var lastTouch: TouchLog?
    @State private var showUndoToast = false
    @State private var showFocusMode = false
    @State private var focusProject: Project?
    @State private var showAddStone = false
    @State private var showSpeechInput = false
    @State private var showSessionLog = false
    @State private var selectedProject: Project?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dateHeader
                    realitySection
                    dayMessageSection
                    projectsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarHidden(true)
            .onAppear { computeDayState() }
            .onChange(of: allStones.count) { computeDayState() }
            .overlay(alignment: .bottom) { undoToast }
            .sheet(isPresented: $showFocusMode) {
                if let project = focusProject {
                    FocusModeView(project: project) {
                        showFocusMode = false
                    }
                }
            }
            .sheet(isPresented: $showAddStone) {
                StoneEventFormView { stone in
                    modelContext.insert(stone)
                    computeDayState()
                }
            }
            .sheet(isPresented: $showSpeechInput) {
                SpeechStoneInputView()
            }
            .sheet(isPresented: $showSessionLog) {
                if let project = selectedProject {
                    PhasedSessionLogSheet(project: project) { touch in
                        modelContext.insert(touch)
                        lastTouch = touch
                        withAnimation {
                            showUndoToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation {
                                if lastTouch?.id == touch.id {
                                    showUndoToast = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateString)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Acknowledging reality, not managing it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Reality Section (Stones)

    private var realitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text("Reality")
                    .font(.headline)
                Spacer()

                Button {
                    showSpeechInput = true
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.blue)
                }

                Button {
                    showAddStone = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
            }

            if dayState.stoneInstances.isEmpty {
                Text("No fixed events today")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(dayState.stoneInstances) { instance in
                        StoneRow(instance: instance)
                    }
                }
            }

            // Show free time summary
            if !dayState.freeSlots.isEmpty {
                let totalFree = dayState.freeSlots.reduce(0) { $0 + $1.durationMinutes }
                Text("\(freeTimeLabel(totalFree)) available")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func freeTimeLabel(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }

    // MARK: - Day Message

    private var dayMessageSection: some View {
        Text(dayState.dayMessage)
            .font(.title3)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    // MARK: - Projects Section

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Things worth touching today")
                    .font(.headline)
                Spacer()
                Text("no need to be exact")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if activeProjects.isEmpty {
                emptyProjectsState
            } else {
                VStack(spacing: 8) {
                    ForEach(activeProjects) { project in
                        ProjectTouchRow(project: project) {
                            if project.hasStrategicPlan {
                                selectedProject = project
                                showSessionLog = true
                            } else {
                                touchProject(project)
                            }
                        } onFocus: {
                            startFocus(project)
                        }
                    }
                }
            }
        }
    }

    private var emptyProjectsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No active projects")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Add a project to start tracking your work")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Undo Toast

    @ViewBuilder
    private var undoToast: some View {
        if showUndoToast, let touch = lastTouch {
            HStack {
                Text("Logged touch for \(touch.projectTitle)")
                    .font(.subheadline)
                Spacer()
                Button("Undo") {
                    undoTouch()
                }
                .fontWeight(.semibold)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func computeDayState() {
        dayState.compute(stones: allStones, projects: activeProjects)
    }

    private func touchProject(_ project: Project) {
        let touch = TouchLog(project: project)
        modelContext.insert(touch)
        lastTouch = touch

        withAnimation {
            showUndoToast = true
        }

        // Hide toast after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                if lastTouch?.id == touch.id {
                    showUndoToast = false
                }
            }
        }
    }

    private func undoTouch() {
        if let touch = lastTouch {
            modelContext.delete(touch)
            withAnimation {
                showUndoToast = false
                lastTouch = nil
            }
        }
    }

    private func startFocus(_ project: Project) {
        focusProject = project
        showFocusMode = true
    }
}

// MARK: - Stone Row

struct StoneRow: View {
    let instance: StoneEventInstance

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 8, height: 8)

            Text(instance.timeString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(instance.title)
                .font(.subheadline)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Project Touch Row

struct ProjectTouchRow: View {
    let project: Project
    let onTouch: () -> Void
    let onFocus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: title and touch button
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(project.title)
                            .font(.body)
                            .fontWeight(.medium)

                        if project.hasStrategicPlan, let archetype = project.archetype {
                            Text(archetype.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    // Phase info for strategic projects
                    if project.hasStrategicPlan {
                        if let phase = project.activePhase {
                            Text("Phase: \(phase.title) (\(phase.progressString))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let phase = project.currentPhase {
                        Text(phase)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if project.touchCountToday > 0 {
                    Text("Touched \(project.touchCountToday)x")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Menu {
                    Button {
                        onTouch()
                    } label: {
                        Label("Log Touch", systemImage: "hand.tap")
                    }

                    Button {
                        onFocus()
                    } label: {
                        Label("Focus Mode", systemImage: "scope")
                    }
                } label: {
                    Image(systemName: "hand.tap.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }

            // Next session info for strategic projects
            if project.hasStrategicPlan, let nextSession = project.nextPlannedSession {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text("Next: \(nextSession.title)")
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Text(nextSession.formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let mentalRule = nextSession.mentalRule {
                        Text("\"\(mentalRule)\"")
                            .font(.caption2)
                            .italic()
                            .foregroundStyle(.purple.opacity(0.8))
                    }

                    if let goal = nextSession.goal {
                        Text("Goal: \(goal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            // Progress bar for strategic projects
            if project.hasStrategicPlan && project.totalSessionCount > 0 {
                ProgressView(value: project.progress)
                    .tint(.purple)

                Text(project.progressString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    TodayView()
        .modelContainer(for: [Project.self, StoneEvent.self, TouchLog.self], inMemory: true)
}
