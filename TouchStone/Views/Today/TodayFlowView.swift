import SwiftUI
import SwiftData

// MARK: - Today Flow View

/// Main workflow view showing the daily schedule as a merged timeline.
/// Displays stones (fixed events) and waters (suggested sessions) in chronological order.
struct TodayFlowView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var allStones: [StoneEvent]

    @Query(filter: #Predicate<Project> { $0.isActive }, sort: \Project.createdAt, order: .reverse)
    private var activeProjects: [Project]

    @Query private var dayPlans: [DayPlan]

    @Query(filter: #Predicate<Rule> { $0.isActive })
    private var activeRules: [Rule]

    @State private var dayState: DayState = DayState()
    @State private var selectedDate = Date()
    @State private var showZenMode = false
    @State private var focusProject: Project?
    @State private var lastTouch: TouchLog?
    @State private var showUndoToast = false
    @State private var showAddStone = false
    @State private var showSpeechInput = false
    @State private var showEditMode = false

    private let calendar = Calendar.current

    // MARK: - Day Plan Computed Properties

    /// Get today's DayPlan if it exists
    private var todaysPlan: DayPlan? {
        let today = calendar.startOfDay(for: selectedDate)
        return dayPlans.first { calendar.isDate($0.date, inSameDayAs: today) }
    }

    /// Whether to show the "Do you want to work today?" prompt
    private var showWorkPrompt: Bool {
        // Only show for today, not future dates
        calendar.isDateInToday(selectedDate) && todaysPlan?.hasDecided != true
    }

    /// Whether user has confirmed they want to work today
    private var isWorkDayActive: Bool {
        todaysPlan?.isWorkDay == true
    }

    /// Whether user declined to work today
    private var isRestDay: Bool {
        todaysPlan?.isRestDay == true
    }

    /// All active, non-completed projects available for touching anytime
    private var additionalProjects: [Project] {
        activeProjects.filter { project in
            // If project has planned hours, check if there's remaining work
            if project.totalPlannedMinutes > 0 {
                return project.remainingHours > 0
            }
            // Projects without planned hours are always included
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(uiColor: UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1.0))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Date tabs
                    dateTabsView
                        .padding(.top, 16)

                    // Main content
                    ScrollView {
                        FlowTimelineView(
                            items: dayState.workflowItems,
                            additionalProjects: additionalProjects,
                            isToday: calendar.isDateInToday(selectedDate),
                            onTouch: touchProject,
                            onFocus: { project in focusProject = project },
                            onDelete: isWorkDayActive ? deleteFlowItem : nil,
                            onEditMode: isWorkDayActive ? { showEditMode = true } : nil
                        )
                        .padding(.top, 16)
                        // Add padding at bottom when prompt is showing
                        .padding(.bottom, showWorkPrompt ? 140 : 0)
                    }
                }

                // Work prompt overlay at bottom
                if showWorkPrompt {
                    VStack {
                        Spacer()
                        WorkTodayPromptView(
                            onConfirmWork: confirmWorkToday,
                            onDeclineWork: declineWorkToday
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarHidden(true)
            .onAppear { computeDayState() }
            .onChange(of: allStones.count) { computeDayState() }
            .onChange(of: selectedDate) { computeDayState() }
            .overlay(alignment: .bottom) { undoToast }
            .sheet(isPresented: $showAddStone) {
                StoneEventFormView(onSave: { stone in
                    modelContext.insert(stone)
                    computeDayState()
                })
            }
            .sheet(isPresented: $showSpeechInput) {
                SpeechStoneInputView(initialDate: selectedDate)
            }
            .sheet(item: $focusProject) { project in
                FocusModeView(project: project) {
                    focusProject = nil
                }
            }
            .sheet(isPresented: $showEditMode) {
                if let plan = todaysPlan {
                    FlowEditModeView(
                        dayPlan: plan,
                        allProjects: Array(activeProjects),
                        onDismiss: {
                            showEditMode = false
                            computeDayState()
                        }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Flow")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(headerDateString)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
            }

            Spacer()

            // Zen Mode button
            Button {
                showZenMode = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                    Text("Zen Mode")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                )
            }
        }
    }

    private var headerDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d \u{00B7} EEEE"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Date Tabs

    private var dateTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(upcomingDates, id: \.self) { date in
                    DateTabButton(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var upcomingDates: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))
        }
    }

    // MARK: - Undo Toast

    @ViewBuilder
    private var undoToast: some View {
        if showUndoToast, let touch = lastTouch {
            HStack {
                Text("Logged touch for \(touch.projectTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Button("Undo") {
                    undoTouch()
                }
                .fontWeight(.semibold)
                .foregroundStyle(.teal)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6).opacity(0.9))
            )
            .shadow(radius: 4)
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func computeDayState() {
        dayState = DayState(date: selectedDate)

        // Check if we have a persisted schedule for today
        if let plan = todaysPlan, plan.isWorkDay, plan.hasSchedule {
            // Auto-skip expired sessions first
            DayState.autoSkipExpiredSessions(dayPlan: plan)
            // Load from persisted schedule (locked-in times)
            dayState.loadFromPersistedSchedule(dayPlan: plan, stones: Array(allStones))
        } else if isRestDay && calendar.isDateInToday(selectedDate) {
            // Rest day - only show stones (no work suggestions)
            dayState.computeStonesOnly(stones: Array(allStones))
        } else {
            // Preview mode (before "Let's go") - compute ephemeral suggestions
            dayState.compute(stones: Array(allStones), projects: Array(activeProjects), rules: Array(activeRules))
        }
    }

    /// User confirmed they want to work today - record start time and lock in schedule
    private func confirmWorkToday() {
        let plan = getOrCreateTodayPlan()
        plan.wantsToWork = true
        plan.startedAt = Date()

        // Generate and persist the schedule NOW (one-time, locked in)
        dayState.commitSchedule(
            to: plan,
            context: modelContext,
            stones: Array(allStones),
            projects: Array(activeProjects)
        )

        withAnimation(.easeInOut(duration: 0.3)) {
            computeDayState()
        }
    }

    /// User declined to work today - hide work suggestions
    private func declineWorkToday() {
        let plan = getOrCreateTodayPlan()
        plan.wantsToWork = false

        withAnimation(.easeInOut(duration: 0.3)) {
            computeDayState()
        }
    }

    /// Get or create today's DayPlan
    private func getOrCreateTodayPlan() -> DayPlan {
        if let existing = todaysPlan {
            return existing
        }
        let newPlan = DayPlan(date: selectedDate)
        modelContext.insert(newPlan)
        return newPlan
    }

    private func touchProject(_ project: Project) {
        let touch = TouchLog(project: project)
        modelContext.insert(touch)
        lastTouch = touch

        // If we have a persisted schedule, mark the corresponding session as completed
        if let plan = todaysPlan, plan.hasSchedule {
            // Find a pending session for this project and mark it completed
            if let session = plan.scheduledSessions.first(where: {
                $0.project?.id == project.id && $0.status == .pending
            }) {
                session.complete(with: touch)
            }
        }

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

        // Don't recompute - items stay in place as daily summary
        // Ghost/solid styling updates automatically via SwiftData
    }

    private func deleteFlowItem(_ item: WorkflowItem) {
        guard let plan = todaysPlan, plan.hasSchedule else { return }
        guard let project = item.project else { return }

        // Find the scheduled session matching this workflow item
        if let session = plan.scheduledSessions.first(where: {
            $0.project?.id == project.id &&
            $0.scheduledStart == item.startTime &&
            $0.scheduledEnd == item.endTime
        }) {
            modelContext.delete(session)

            // Recompute to update the view
            withAnimation(.easeInOut(duration: 0.3)) {
                computeDayState()
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
            // Don't recompute - styling updates automatically
        }
    }
}

// MARK: - Date Tab Button

struct DateTabButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: action) {
            Text(buttonLabel)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .teal : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.teal.opacity(0.2) : Color.clear)
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? Color.teal.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var buttonLabel: String {
        if isToday {
            return "Today"
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        if calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    TodayFlowView()
        .modelContainer(for: [Project.self, StoneEvent.self, TouchLog.self, Rule.self], inMemory: true)
}
