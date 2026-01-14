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

    @State private var dayState = DayState()
    @State private var selectedDate = Date()
    @State private var showZenMode = false
    @State private var focusProject: Project?
    @State private var lastTouch: TouchLog?
    @State private var showUndoToast = false
    @State private var showAddStone = false
    @State private var showSpeechInput = false

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

    /// Projects not scheduled in the flow - available for additional touches
    private var additionalProjects: [Project] {
        // Get IDs of projects already in the workflow
        let scheduledProjectIds = Set(
            dayState.workflowItems
                .compactMap { $0.project?.id }
        )
        // Return active projects not already scheduled
        return activeProjects.filter { !scheduledProjectIds.contains($0.id) }
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
                            onTouch: touchProject,
                            onFocus: { project in focusProject = project }
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
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center) {
            // Menu button
            Button {
                showAddStone = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }

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
            .padding(.leading, 8)

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

        // If it's a rest day, only show stones (no work suggestions)
        if isRestDay && calendar.isDateInToday(selectedDate) {
            dayState.computeStonesOnly(stones: Array(allStones))
        } else {
            dayState.compute(stones: Array(allStones), projects: Array(activeProjects))
        }
    }

    /// User confirmed they want to work today - record start time
    private func confirmWorkToday() {
        let plan = getOrCreateTodayPlan()
        plan.wantsToWork = true
        plan.startedAt = Date()

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
        .modelContainer(for: [Project.self, StoneEvent.self, TouchLog.self], inMemory: true)
}
