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

    @Query private var allTouchLogs: [TouchLog]

    @Query private var dayContexts: [DayContext]

    @State private var dayState: DayState = DayState()
    @State private var selectedDate = Date()
    @State private var focusProject: Project?
    @State private var lastTouch: TouchLog?
    @State private var showUndoToast = false
    @State private var showAddStone = false
    @State private var showSpeechInput = false
    @State private var showCapacityAlert = false
    @State private var pendingTouchProject: Project?
    @State private var pullOffset: CGFloat = 0
    @State private var initialScrollY: CGFloat?
    @State private var isResetting = false
    @State private var showCelebration = false
    @State private var showResetConfirmation = false
    @State private var lastHapticProgress: Int = 0

    private let calendar = Calendar.current
    private let resetThreshold: CGFloat = 100

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

    /// Today's touch logs
    private var todayTouchLogs: [TouchLog] {
        let today = calendar.startOfDay(for: Date())
        return allTouchLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
    }

    /// Total touched minutes today
    private var todayTotalMinutes: Int {
        todayTouchLogs.reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.sm)

                    // Date tabs
                    dateTabsView
                        .padding(.top, DesignSystem.Spacing.lg)

                    // Main content
                    scrollContent
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

                // Rest day - show option to change mind
                if isRestDay && calendar.isDateInToday(selectedDate) {
                    VStack {
                        Spacer()
                        Button {
                            resetTodayPlan()
                        } label: {
                            Text("Changed my mind? Tap to start working")
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.cardBackground)
                                )
                        }
                        .padding(.bottom, 30)
                    }
                    .transition(.opacity)
                }

                // Touch celebration overlay
                TouchCelebrationView(
                    isShowing: showCelebration,
                    accentColor: DesignSystem.Colors.accent
                )
            }
            .navigationBarHidden(true)
            .onAppear { computeDayState() }
            .onChange(of: allStones.count) { rescheduleIfNeeded() }
            .onChange(of: selectedDate) {
                initialScrollY = nil  // Reset scroll tracking for new date
                computeDayState()
            }
            .overlay(alignment: .bottom) { undoToast }
            .alert("Great work today!", isPresented: $showCapacityAlert) {
                Button("Take a break") {
                    pendingTouchProject = nil
                }
                Button("Keep going") {
                    if let project = pendingTouchProject {
                        performTouch(project)
                        pendingTouchProject = nil
                    }
                }
            } message: {
                Text("You've reached your daily goal. Consider doing something else, or continue if you'd like.")
            }
            .alert("Reset Today?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset Day", role: .destructive) {
                    performDayReset()
                }
            } message: {
                Text("This will clear all \(todayTouchLogs.count) touch log\(todayTouchLogs.count == 1 ? "" : "s") and reset your day. This cannot be undone.")
            }
            .sheet(isPresented: $showAddStone) {
                StoneEventFormView(onSave: { stone in
                    modelContext.insert(stone)
                    // Reschedule happens via onChange(of: allStones.count)
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
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Flow")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(headerDateString)
                    .font(DesignSystem.Typography.captionBold)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.5)
            }

            Spacer()
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

    // MARK: - Scroll Content

    private var scrollContent: some View {
        let deleteHandler: ((WorkflowItem) -> Void)? = isWorkDayActive ? { item in self.deleteFlowItem(item) } : nil
        let bottomPadding: CGFloat = showWorkPrompt ? 140 : 0

        return ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                // Pull detector - measures position to detect over-scroll
                Color.clear
                    .frame(height: 1)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetKey.self,
                                    value: geometry.frame(in: .global).minY
                                )
                        }
                    )

                // Hidden reset indicator - revealed when pulling
                ZStack {
                    if pullOffset > 0 {
                        pullToResetIndicator
                    }
                }
                .frame(height: pullOffset > 0 ? pullOffset : 0)
                .clipped()

                FlowTimelineView(
                        items: dayState.workflowItems,
                        additionalProjects: additionalProjects,
                        isToday: calendar.isDateInToday(selectedDate),
                        onTouch: touchProject,
                        onFocus: { project in focusProject = project },
                        onDelete: deleteHandler,
                        onDeleteStone: { stone in deleteStone(stone) },
                        onEditMode: nil
                    )
                    .padding(.top, 16)
                    .padding(.bottom, bottomPadding)
            }
        }
        .onPreferenceChange(ScrollOffsetKey.self) { minY in
            if initialScrollY == nil {
                initialScrollY = minY
            }

            guard let initial = initialScrollY else { return }

            // Only track over-scroll (pulling past the top)
            let pulled = max(0, minY - initial)
            pullOffset = pulled

            // Progressive haptic feedback every 30pt
            let currentProgress = Int(pullOffset / 30)
            if currentProgress > lastHapticProgress && pullOffset < resetThreshold {
                HapticService.lightTap()
                lastHapticProgress = currentProgress
            }

            // Trigger reset logic
            if !isResetting && pullOffset >= resetThreshold {
                isResetting = true
                HapticService.mediumTap()
            } else if isResetting && pullOffset < 10 {
                showResetConfirmation = true
                isResetting = false
                lastHapticProgress = 0
            } else if pullOffset < 10 {
                lastHapticProgress = 0
            }
        }
    }

    // MARK: - Pull to Reset Indicator (Hidden behind content)

    private var pullToResetIndicator: some View {
        let progress = min(pullOffset / resetThreshold, 1.0)
        let isPastThreshold = pullOffset >= resetThreshold
        let accentColor = DesignSystem.Colors.accent

        return VStack {
            Spacer()

            VStack(spacing: DesignSystem.Spacing.sm) {
                // Progress ring with icon
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 2.5)
                        .frame(width: 40, height: 40)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            accentColor,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))

                    // Icon
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .rotationEffect(.degrees(-360 * progress))
                }
                .scaleEffect(isPastThreshold ? 1.15 : 0.8 + (0.2 * progress))
                .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPastThreshold)
                .animation(.spring(response: 0.25, dampingFraction: 0.65), value: progress)

                // Text - only show when pulled enough
                Text(isPastThreshold ? "Release to reset" : "Reset day")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isPastThreshold ? accentColor : DesignSystem.Colors.textSecondary)
                    .opacity(pullOffset > 40 ? min((pullOffset - 40) / 30, 1.0) : 0)
            }
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.background)
    }

    private func performDayReset() {
        // Delete all touch logs for today
        let logsToDelete = todayTouchLogs
        for touchLog in logsToDelete {
            modelContext.delete(touchLog)
        }

        // Clear undo state
        lastTouch = nil
        showUndoToast = false

        // Reset the day plan
        resetTodayPlan()

        // Success feedback after reset
        HapticService.success()
    }

    // MARK: - Undo Toast

    @ViewBuilder
    private var undoToast: some View {
        if showUndoToast, let touch = lastTouch {
            HStack {
                Text("Logged touch for \(touch.projectTitle)")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                Button("Undo") {
                    undoTouch()
                }
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.accent)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(DesignSystem.Colors.cardBackground)
                    .shadow(radius: 4)
            )
            .padding(DesignSystem.Spacing.lg)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }


    // MARK: - Actions

    private func computeDayState() {
        dayState = DayState(date: selectedDate)

        if isRestDay && calendar.isDateInToday(selectedDate) {
            // Rest day - only show stones (no work suggestions)
            dayState.computeStonesOnly(stones: Array(allStones))
        } else {
            // Compute suggestions dynamically based on stones, projects, rules, and day contexts
            dayState.compute(
                stones: Array(allStones),
                projects: Array(activeProjects),
                rules: Array(activeRules),
                contexts: Array(dayContexts)
            )
        }
    }

    /// User confirmed they want to work today - record start time
    private func confirmWorkToday() {
        HapticService.confirmDay()
        let plan = getOrCreateTodayPlan()
        plan.wantsToWork = true
        plan.startedAt = Date()

        // Commit work day decision (updates backlog)
        dayState.commitWorkDay(
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
        HapticService.buttonPress()
        let plan = getOrCreateTodayPlan()
        plan.wantsToWork = false

        withAnimation(.easeInOut(duration: 0.3)) {
            computeDayState()
        }
    }

    /// Reset today's plan (change mind after declining)
    private func resetTodayPlan() {
        if let plan = todaysPlan {
            plan.wantsToWork = nil
            plan.startedAt = nil
        }

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

    /// Recompute day state when stones change
    private func rescheduleIfNeeded() {
        // Simply recompute the day state - suggestions are generated dynamically
        withAnimation(.easeInOut(duration: 0.3)) {
            computeDayState()
        }
    }

    private func touchProject(_ project: Project) {
        // Check if this touch would exceed daily capacity
        if calendar.isDateInToday(selectedDate) {
            let defaultDuration = 60 // TouchLog default duration
            let newTotal = todayTotalMinutes + defaultDuration
            let capacity = UserPreferences.shared.dailyProductiveMinutes

            if newTotal > capacity {
                // Store pending project and show confirmation
                pendingTouchProject = project
                showCapacityAlert = true
                return
            }
        }

        // Proceed with touch
        performTouch(project)
    }

    /// Actually perform the touch (called directly or after user confirms)
    private func performTouch(_ project: Project) {
        HapticService.success()
        let touch = TouchLog(project: project)

        // If project is in phase mode, link touch to active phase
        if project.isPhaseMode, let activePhase = project.activePhase {
            touch.phase = activePhase
        }

        modelContext.insert(touch)
        lastTouch = touch

        // Trigger celebration
        showCelebration = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showCelebration = false
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
        // Suggestions are computed dynamically, no persisted sessions to delete
        // Just recompute the day state
        withAnimation(.easeInOut(duration: 0.3)) {
            computeDayState()
        }
    }

    private func deleteStone(_ stone: StoneEvent) {
        modelContext.delete(stone)
        withAnimation(.easeInOut(duration: 0.3)) {
            computeDayState()
        }
    }

    private func undoTouch() {
        if let touch = lastTouch {
            HapticService.undo()
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
                .font(DesignSystem.Typography.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? DesignSystem.Colors.accent.opacity(0.2) : Color.clear)
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? DesignSystem.Colors.accent.opacity(0.5) : Color.clear, lineWidth: 1)
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

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    TodayFlowView()
        .modelContainer(for: [Project.self, StoneEvent.self, TouchLog.self, Rule.self, DayPlan.self, Milestone.self], inMemory: true)
}
