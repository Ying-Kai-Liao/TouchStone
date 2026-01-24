import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stones: [StoneEvent]
    @Query private var touchLogs: [TouchLog]
    @Query(filter: #Predicate<Project> { $0.isActive }) private var activeProjects: [Project]
    @Query private var dayContexts: [DayContext]

    @State private var selectedMonth = Date()
    @State private var selectedDay: SelectedDay?
    @State private var showingAddStone = false
    @State private var addStoneDate: Date?
    @State private var showingWorkloadLegend = false
    @State private var showDetailedView = false

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

                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            monthNavigationHeader
                            weekdayHeader
                            calendarGrid
                        }
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                }
            }
            .navigationBarHidden(true)
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

            // Detail view toggle button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showDetailedView.toggle()
                }
            } label: {
                Image(systemName: showDetailedView ? "list.bullet.rectangle.fill" : "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(showDetailedView ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
            }

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

            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedMonth = Date()
                }
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
                withAnimation(.spring(response: 0.3)) {
                    selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
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

            Text(monthYearFormatter.string(from: selectedMonth))
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                }
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

    private var calendarGrid: some View {
        let days = generateCalendarDays()
        let cellHeight: CGFloat = showDetailedView ? 110 : 60

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), count: 7), spacing: DesignSystem.Spacing.md) {
            ForEach(days) { dayData in
                DayCell(
                    dayData: dayData,
                    stones: stonesForDay(dayData.date),
                    contexts: contextsForDay(dayData.date),
                    touchCount: touchCountForDay(dayData.date),
                    dayLoad: loadForDay(dayData.date),
                    hasDeadline: hasDeadlineOnDay(dayData.date),
                    showDetails: showDetailedView,
                    cellHeight: cellHeight,
                    onTap: {
                        if dayData.isCurrentMonth {
                            selectedDay = SelectedDay(
                                date: dayData.date,
                                stones: stonesForDay(dayData.date)
                            )
                        }
                    }
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.bottom, DesignSystem.Spacing.lg)
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

    private func generateCalendarDays() -> [DayData] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
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
                let isCurrentMonth = calendar.isDate(date, equalTo: selectedMonth, toGranularity: .month)
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
        .buttonStyle(.plain)
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

        // DUE tag or context label for deadline days
        if hasDeadline {
            Text("DUE")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.background)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(loadColor)
                )
        } else if isNoWorkDay {
            Text("OFF")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.cardBackground)
                )
        } else {
            Color.clear
                .frame(height: 14)
        }

        Spacer()
            .frame(height: 4)
    }

    // MARK: - Detailed View

    @ViewBuilder
    private func detailedContent(day: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Day number row
            HStack {
                Text("\(day)")
                    .font(.system(size: 12, weight: isToday ? .bold : .medium))
                    .foregroundColor(dayData.isCurrentMonth ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(isToday ? DesignSystem.Colors.accent.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(isToday ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1)
                    )

                Spacer()

                // DUE tag
                if hasDeadline {
                    Text("DUE")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.background)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(loadColor)
                        )
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            // Event list
            if stones.isEmpty {
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(sortedStones.prefix(3)) { stone in
                        HStack(spacing: 2) {
                            Text(stone.startTimeString)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .frame(width: 28, alignment: .leading)

                            Text(stone.title)
                                .font(.system(size: 8, weight: .regular))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .lineLimit(1)
                        }
                    }

                    if stones.count > 3 {
                        Text("+\(stones.count - 3) more")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, 4)

                Spacer()
            }
        }
    }

    /// Color based on workload - smooth accent gradient
    /// No-work days get a special muted background
    private var cellBackgroundColor: Color {
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
}

#Preview {
    CalendarView()
        .modelContainer(for: [StoneEvent.self, TouchLog.self, Project.self, DayContext.self], inMemory: true)
}
