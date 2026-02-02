import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stones: [StoneEvent]
    @Query private var touchLogs: [TouchLog]
    @Query(filter: #Predicate<Project> { $0.isActive }) private var activeProjects: [Project]
    @Query private var dayContexts: [DayContext]

    private var prefs: UserPreferences { UserPreferences.shared }

    @State private var currentMonthDate = Date()
    @State private var monthsToDisplay: [Date] = []
    @State private var currentPageIndex = 2  // Start at center of 5-month window
    @State private var isUpdatingPage = false
    @State private var selectedDay: SelectedDay?
    @State private var showingAddStone = false
    @State private var addStoneDate: Date?
    @State private var showingWorkloadLegend = false

    // Pre-computed day data cache to avoid expensive calculations during swipe
    @State private var dayDataCache: [Date: CachedDayData] = [:]
    @State private var isLoadingCalendarData = true
    @State private var pendingLoadTask: Task<Void, Never>?

    // Buffer size: 5 months (2 before, current, 2 after)
    private let monthBufferSize = 5
    private let centerIndex = 2

    // Cached data for each day to avoid recalculation during swipe
    struct CachedDayData {
        let stones: [StoneEvent]
        let contexts: [DayContext]
        let touchCount: Int
        let dayLoad: Double
        let hasDeadline: Bool
    }

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    struct SelectedDay: Identifiable {
        let id = UUID()
        let date: Date
        let stones: [StoneEvent]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom header
                    headerView
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.top, DesignSystem.Spacing.sm)

                    VStack(spacing: DesignSystem.Spacing.md) {
                        monthNavigationHeader
                        weekdayHeader
                        calendarPager
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                initializeMonthsToDisplay()
            }
            .onChange(of: stones.count) { _, _ in
                precomputeDayDataCacheAsync()
            }
            .onChange(of: activeProjects.count) { _, _ in
                precomputeDayDataCacheAsync()
            }
            .onChange(of: dayContexts.count) { _, _ in
                precomputeDayDataCacheAsync()
            }
            .sheet(item: $selectedDay) { day in
                DayDetailView(
                    date: day.date,
                    stones: day.stones,
                    onAddStone: {
                        let dateToUse = day.date
                        selectedDay = nil
                        // Small delay to allow first sheet to dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            addStoneDate = dateToUse
                            showingAddStone = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showingAddStone) {
                StoneChatInputView(initialDate: addStoneDate)
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center) {
            Text("Calendar")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            // Workload legend help button
            Button {
                showingWorkloadLegend = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .popover(isPresented: $showingWorkloadLegend, arrowEdge: .top) {
                workloadLegendPopover
            }

            // Calendar detail mode toggle - clean icon button
            Button {
                HapticService.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    prefs.calendarDetailMode.toggle()
                }
            } label: {
                Image(systemName: prefs.calendarDetailMode ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(prefs.calendarDetailMode ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(prefs.calendarDetailMode ? DesignSystem.Colors.accent.opacity(0.15) : Color.clear)
                    )
                    .contentShape(Circle())
            }
            .accessibilityLabel(prefs.calendarDetailMode ? "Switch to compact view" : "Switch to detail view")

            Button {
                jumpToMonth(Date())
            } label: {
                Text("Today")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.accent.opacity(0.15))
                    )
            }
        }
    }

    private var workloadLegendPopover: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("WORKLOAD COLORS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.5)

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(WorkloadLevel.allCases, id: \.self) { level in
                    HStack(spacing: DesignSystem.Spacing.md) {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(level.color)
                            .frame(width: 24, height: 24)

                        Text(level.label)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Spacer()
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(width: 160)
        .background(DesignSystem.Colors.cardBackground)
        .presentationCompactAdaptation(.popover)
    }

    private var monthNavigationHeader: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                navigateToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.cardBackground)
                    )
            }

            Spacer()

            Text(monthYearFormatter.string(from: currentMonthDate))
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            Button {
                navigateToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.cardBackground)
                    )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    private var calendarPager: some View {
        TabView(selection: $currentPageIndex) {
            ForEach(Array(monthsToDisplay.enumerated()), id: \.offset) { index, monthDate in
                if isLoadingCalendarData && dayDataCache.isEmpty {
                    skeletonCalendarGrid
                        .tag(index)
                } else {
                    calendarGrid(for: monthDate)
                        .tag(index)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: currentPageIndex) { oldValue, newValue in
            handlePageChange(from: oldValue, to: newValue)
        }
    }

    /// Skeleton grid shown while data loads
    private var skeletonCalendarGrid: some View {
        let cellHeight: CGFloat = prefs.calendarDetailMode ? 100 : 60

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), count: 7), spacing: DesignSystem.Spacing.md) {
            ForEach(0..<35, id: \.self) { _ in
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(DesignSystem.Colors.cardBackground.opacity(0.5))
                    .frame(height: cellHeight)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    private func calendarGrid(for monthDate: Date) -> some View {
        let days = generateCalendarDays(for: monthDate)
        let cellSpacing = prefs.calendarDetailMode ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md
        let cellHeight: CGFloat = prefs.calendarDetailMode ? 100 : 60

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), count: 7), spacing: cellSpacing) {
            ForEach(days) { dayData in
                let cached = getCachedDayData(for: dayData.date)
                DayCell(
                    dayData: dayData,
                    stones: cached.stones,
                    contexts: cached.contexts,
                    touchCount: cached.touchCount,
                    dayLoad: cached.dayLoad,
                    hasDeadline: cached.hasDeadline,
                    showDetails: prefs.calendarDetailMode,
                    cellHeight: cellHeight,
                    onTap: {
                        if dayData.isCurrentMonth {
                            selectedDay = SelectedDay(
                                date: dayData.date,
                                stones: cached.stones
                            )
                        }
                    }
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.lg)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: prefs.calendarDetailMode)
    }

    // MARK: - Day Data Cache

    private func getCachedDayData(for date: Date) -> CachedDayData {
        let dateKey = calendar.startOfDay(for: date)
        if let cached = dayDataCache[dateKey] {
            return cached
        }
        // Return empty placeholder to avoid blocking UI
        // Data will be filled in when async cache completes
        return CachedDayData(
            stones: [],
            contexts: [],
            touchCount: 0,
            dayLoad: 0,
            hasDeadline: false
        )
    }

    private func computeDayData(for date: Date) -> CachedDayData {
        CachedDayData(
            stones: stonesForDay(date),
            contexts: contextsForDay(date),
            touchCount: touchCountForDay(date),
            dayLoad: loadForDay(date),
            hasDeadline: hasDeadlineOnDay(date)
        )
    }

    private func precomputeDayDataCache() {
        var newCache = dayDataCache  // Start with existing cache

        for monthDate in monthsToDisplay {
            let days = generateCalendarDays(for: monthDate)
            for dayData in days where dayData.day != nil {
                let dateKey = calendar.startOfDay(for: dayData.date)
                // Only compute if not already cached
                if newCache[dateKey] == nil {
                    newCache[dateKey] = computeDayData(for: dayData.date)
                }
            }
        }

        dayDataCache = newCache
    }

    /// Async wrapper for cache precomputation
    private func precomputeDayDataCacheAsync() {
        Task { @MainActor in
            await Task.yield()
            precomputeDayDataCache()
        }
    }

    /// Prefetch a single month's data in background (for smoother swiping)
    private func prefetchMonthData(for monthDate: Date) {
        Task { @MainActor in
            await Task.yield()
            let days = generateCalendarDays(for: monthDate)
            var updatedCache = dayDataCache

            for dayData in days where dayData.day != nil {
                let dateKey = calendar.startOfDay(for: dayData.date)
                if updatedCache[dateKey] == nil {
                    updatedCache[dateKey] = computeDayData(for: dayData.date)
                }
            }

            dayDataCache = updatedCache
        }
    }

    // MARK: - Month Navigation

    private func initializeMonthsToDisplay() {
        // Show calendar structure immediately
        updateMonthsWindow(centerMonth: currentMonthDate)
        currentPageIndex = centerIndex

        // Load data asynchronously
        Task { @MainActor in
            await Task.yield()  // Allow UI to render first
            precomputeDayDataCache()
            isLoadingCalendarData = false
        }
    }

    private func updateMonthsWindow(centerMonth: Date) {
        // Generate 5 months: -2, -1, center, +1, +2
        var months: [Date] = []
        for offset in -2...2 {
            if let month = calendar.date(byAdding: .month, value: offset, to: centerMonth) {
                months.append(month)
            }
        }
        monthsToDisplay = months
    }

    private func handlePageChange(from oldIndex: Int, to newIndex: Int) {
        guard !monthsToDisplay.isEmpty, !isUpdatingPage else { return }

        // Update the displayed month in header based on current page
        if newIndex >= 0 && newIndex < monthsToDisplay.count {
            currentMonthDate = monthsToDisplay[newIndex]
        }

        // Don't load data during swipe - wait for swipe to finish
        // Load data for current month after a short delay (swipe settled)
        loadDataAfterSwipe(for: newIndex)

        // Only rebalance when we're getting close to the edges (0 or 4)
        // This gives us a buffer so the reset happens less frequently
        if newIndex <= 0 || newIndex >= monthBufferSize - 1 {
            isUpdatingPage = true

            // Wait for the swipe animation to fully complete before rebalancing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                rebalanceMonthsWindow()
            }
        }
    }

    /// Debounced data loading - only loads after swipe settles
    private func loadDataAfterSwipe(for pageIndex: Int) {
        // Cancel any pending load
        pendingLoadTask?.cancel()

        // Wait for swipe to settle before loading
        pendingLoadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)  // 150ms debounce

            guard !Task.isCancelled else { return }
            guard pageIndex >= 0 && pageIndex < monthsToDisplay.count else { return }

            // Load data for the settled month
            prefetchMonthData(for: monthsToDisplay[pageIndex])
        }
    }

    private func rebalanceMonthsWindow() {
        // Regenerate months centered on current month
        updateMonthsWindow(centerMonth: currentMonthDate)

        // Reset to center without animation
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentPageIndex = centerIndex
        }

        // Precompute cache async and allow next update after
        Task { @MainActor in
            await Task.yield()
            precomputeDayDataCache()
            isUpdatingPage = false
        }
    }

    private func navigateToPreviousMonth() {
        guard !isUpdatingPage, currentPageIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPageIndex -= 1
        }
    }

    private func navigateToNextMonth() {
        guard !isUpdatingPage, currentPageIndex < monthsToDisplay.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPageIndex += 1
        }
    }

    private func jumpToMonth(_ date: Date) {
        currentMonthDate = date
        updateMonthsWindow(centerMonth: date)
        currentPageIndex = centerIndex
    }

    // MARK: - Workload Legend

    private var energyGradientLegend: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("WORKLOAD")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.5)

            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(WorkloadLevel.allCases, id: \.self) { level in
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .fill(level.color)
                            .frame(height: 44)

                        Text(level.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.top, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.xxl)
    }

    enum WorkloadLevel: CaseIterable {
        case free, light, moderate, busy, full

        var label: String {
            switch self {
            case .free: return "FREE"
            case .light: return "LIGHT"
            case .moderate: return "MODERATE"
            case .busy: return "BUSY"
            case .full: return "FULL"
            }
        }

        var color: Color {
            switch self {
            case .free:
                return DesignSystem.Colors.cardBackground
            case .light:
                return DesignSystem.Colors.accent.opacity(0.2)
            case .moderate:
                return DesignSystem.Colors.accent.opacity(0.4)
            case .busy:
                return DesignSystem.Colors.accent.opacity(0.6)
            case .full:
                return DesignSystem.Colors.accent.opacity(0.8)
            }
        }

        /// Returns the workload level for a given load value
        static func forLoad(_ load: Double) -> WorkloadLevel {
            switch load {
            case ..<0.01: return .free
            case ..<0.25: return .light
            case ..<0.5: return .moderate
            case ..<0.75: return .busy
            default: return .full
            }
        }

        /// Returns a smooth gradient color based on exact load percentage
        static func gradientColor(for load: Double) -> Color {
            if load < 0.01 {
                return DesignSystem.Colors.cardBackground
            }
            // Smooth accent gradient from 0.15 to 0.8 opacity based on load
            let clampedLoad = min(load, 1.0)
            let opacity = 0.15 + (clampedLoad * 0.65)
            return DesignSystem.Colors.accent.opacity(opacity)
        }
    }

    private func generateCalendarDays(for monthDate: Date) -> [DayData] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysInMonth = calendar.component(.day, from: monthEnd)

        var days: [DayData] = []

        // Leading empty cells
        for _ in 1..<firstWeekday {
            days.append(DayData(date: Date.distantPast, day: nil, isCurrentMonth: false))
        }

        // Days of the month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                let isCurrentMonth = calendar.isDate(date, equalTo: monthDate, toGranularity: .month)
                days.append(DayData(date: date, day: day, isCurrentMonth: isCurrentMonth))
            }
        }

        return days
    }

    private func stonesForDay(_ date: Date) -> [StoneEvent] {
        stones.filter { stone in
            stone.occursOn(date: date)
        }
    }

    private func touchCountForDay(_ date: Date) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return 0
        }

        return touchLogs.filter { log in
            log.timestamp >= startOfDay && log.timestamp < endOfDay
        }.count
    }

    private func loadForDay(_ date: Date) -> Double {
        return PressureCalculator.calculateDayLoad(
            for: date,
            projects: Array(activeProjects),
            stones: Array(stones),
            contexts: Array(dayContexts)
        )
    }

    private func contextsForDay(_ date: Date) -> [DayContext] {
        dayContexts.filter { $0.appliesTo(date: date) }
    }

    private func hasDeadlineOnDay(_ date: Date) -> Bool {
        return PressureCalculator.hasDeadline(on: date, projects: Array(activeProjects))
    }

    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
}

struct DayData: Identifiable {
    let id = UUID()
    let date: Date
    let day: Int?
    let isCurrentMonth: Bool
}

struct DayCell: View {
    let dayData: DayData
    let stones: [StoneEvent]
    let contexts: [DayContext]
    let touchCount: Int
    let dayLoad: Double  // 0.0 = empty, 1.0 = full, >1.0 = overloaded
    let hasDeadline: Bool
    let showDetails: Bool
    let cellHeight: CGFloat
    let onTap: () -> Void

    private let calendar = Calendar.current

    // TimeTree-style event color palette
    private static let eventColors: [Color] = [
        .red.opacity(0.85),
        .green.opacity(0.75),
        .orange.opacity(0.85),
        .yellow.opacity(0.85),
        .pink.opacity(0.75),
        .cyan.opacity(0.75),
        .purple.opacity(0.75)
    ]

    /// Get a consistent color for a stone based on its ID
    private func eventColor(for stone: StoneEvent) -> Color {
        let index = abs(stone.id.hashValue) % Self.eventColors.count
        return Self.eventColors[index]
    }

    private var sortedStones: [StoneEvent] {
        stones.sorted { ($0.startHour * 60 + $0.startMinute) < ($1.startHour * 60 + $1.startMinute) }
    }

    /// Primary context for display (strictest work mode)
    private var primaryContext: DayContext? {
        contexts.min { $0.workMode.priority < $1.workMode.priority }
    }

    /// Whether this is a no-work day
    private var isNoWorkDay: Bool {
        contexts.strictestWorkMode(for: dayData.date) == .none
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if let day = dayData.day {
                    if showDetails {
                        detailedContent(day: day)
                    } else {
                        compactContent(day: day)
                    }
                } else {
                    Color.clear
                        .frame(height: cellHeight)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(cellBackgroundColor)
            )
        }
        .buttonStyle(PressableDayCellStyle())
        .accessibilityLabel(accessibilityDayLabel)
        .accessibilityHint("Tap to view day details")
    }

    // MARK: - Compact View (Original)

    @ViewBuilder
    private func compactContent(day: Int) -> some View {
        Spacer()

        // Context badge overlay in top-right corner
        ZStack(alignment: .topTrailing) {
            // Day number
            Text("\(day)")
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(dayData.isCurrentMonth ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary.opacity(0.3))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(isToday ? DesignSystem.Colors.accent.opacity(0.2) : Color.clear)
                )
                .overlay(
                    Circle()
                        .strokeBorder(isToday ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1.5)
                )

            // Context type icon
            if let context = primaryContext {
                Image(systemName: context.type.icon)
                    .font(.system(size: 8))
                    .foregroundStyle(DesignSystem.Colors.background)
                    .frame(width: 12, height: 12)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                    )
                    .offset(x: 4, y: -4)
            }
        }

        Spacer()

        // Event indicators (stone dots)
        HStack(spacing: 3) {
            if !stones.isEmpty {
                ForEach(stones.prefix(3)) { _ in
                    Circle()
                        .fill(DesignSystem.Colors.textTertiary)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(height: 6)

        // DUE tag or OFF label
        if hasDeadline {
            Text("DUE")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.accent)
                )
        } else if isNoWorkDay {
            Text("OFF")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                )
        } else {
            Color.clear
                .frame(height: 16)
        }

        Spacer()
            .frame(height: 4)
    }

    // MARK: - Detailed View (TimeTree Style)

    /// Day number color based on weekday (TimeTree style)
    private var dayNumberColor: Color {
        guard dayData.isCurrentMonth else {
            return DesignSystem.Colors.textTertiary.opacity(0.3)
        }
        let weekday = calendar.component(.weekday, from: dayData.date)
        switch weekday {
        case 1: // Sunday
            return .red
        case 7: // Saturday
            return .blue
        default: // Weekdays
            return DesignSystem.Colors.textPrimary
        }
    }

    @ViewBuilder
    private func detailedContent(day: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            // Day number (TimeTree style - colored by weekday, filled circle for today)
            Text("\(day)")
                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .white : dayNumberColor)
                .frame(width: 18, height: 18)
                .background(
                    Circle()
                        .fill(isToday ? Color(white: 0.25) : Color.clear)
                )
                .padding(.leading, 1)
                .padding(.top, 2)

            // Event list as colored pills (edge-to-edge for max title space)
            if stones.isEmpty {
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(sortedStones.prefix(3)) { stone in
                        eventPill(stone: stone)
                    }

                    if stones.count > 3 {
                        Text("+\(stones.count - 3)")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .padding(.leading, 1)
                    }
                }

                Spacer()
            }
        }
    }

    /// Single event as a colored pill (TimeTree style)
    @ViewBuilder
    private func eventPill(stone: StoneEvent) -> some View {
        Text(stone.title)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 3)
            .padding(.vertical, 1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(eventColor(for: stone))
            )
    }

    /// Color based on workload - smooth accent gradient (compact view only)
    /// Detail view uses clean, clear backgrounds (TimeTree style)
    private var cellBackgroundColor: Color {
        // Detail view: no cell background (TimeTree style)
        if showDetails {
            return Color.clear
        }

        if !dayData.isCurrentMonth {
            return Color.clear
        }

        // No-work days (none mode) get a special background
        if isNoWorkDay {
            return DesignSystem.Colors.textTertiary.opacity(0.15)
        }

        // Use smooth gradient color based on exact load percentage
        return CalendarView.WorkloadLevel.gradientColor(for: dayLoad)
    }

    /// Color for deadline badges - always accent color
    private var loadColor: Color {
        return DesignSystem.Colors.accent
    }

    private var isToday: Bool {
        guard dayData.isCurrentMonth else { return false }
        return calendar.isDateInToday(dayData.date)
    }

    private var isWeekend: Bool {
        let weekday = calendar.component(.weekday, from: dayData.date)
        return weekday == 1 || weekday == 7  // Sunday or Saturday
    }

    /// Accessibility label describing the day for VoiceOver
    private var accessibilityDayLabel: String {
        guard let day = dayData.day else { return "" }
        var label = "Day \(day)"
        if isToday { label += ", today" }
        if !stones.isEmpty { label += ", \(stones.count) event\(stones.count == 1 ? "" : "s")" }
        if hasDeadline { label += ", has deadline" }
        if isNoWorkDay { label += ", day off" }
        return label
    }
}

/// Button style for pressable calendar day cells with scale, highlight, and haptic feedback
struct PressableDayCellStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(DesignSystem.Colors.accent.opacity(configuration.isPressed ? 0.15 : 0))
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                if isPressed && !wasPressed {
                    HapticService.selection()
                }
            }
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [StoneEvent.self, TouchLog.self, Project.self, DayContext.self], inMemory: true)
}
