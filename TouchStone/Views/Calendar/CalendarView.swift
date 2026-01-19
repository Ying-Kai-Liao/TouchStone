import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stones: [StoneEvent]
    @Query private var touchLogs: [TouchLog]
    @Query(filter: #Predicate<Project> { $0.isActive }) private var activeProjects: [Project]

    @State private var selectedMonth = Date()
    @State private var selectedDay: SelectedDay?
    @State private var showingAddStone = false
    @State private var addStoneDate: Date?

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
                            energyGradientLegend
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
                SpeechStoneInputView(initialDate: addStoneDate)
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

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), count: 7), spacing: DesignSystem.Spacing.md) {
            ForEach(days) { dayData in
                DayCell(
                    dayData: dayData,
                    stones: stonesForDay(dayData.date),
                    touchCount: touchCountForDay(dayData.date),
                    dayLoad: loadForDay(dayData.date),
                    hasDeadline: hasDeadlineOnDay(dayData.date),
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
        case free, light, busy, full, over

        var label: String {
            switch self {
            case .free: return "FREE"
            case .light: return "LIGHT"
            case .busy: return "BUSY"
            case .full: return "FULL"
            case .over: return "OVER"
            }
        }

        var color: Color {
            switch self {
            case .free:
                return DesignSystem.Colors.cardBackground
            case .light:
                return DesignSystem.Colors.accent.opacity(0.25)
            case .busy:
                return DesignSystem.Colors.accent.opacity(0.5)
            case .full:
                return DesignSystem.Colors.warning.opacity(0.6)
            case .over:
                return DesignSystem.Colors.error.opacity(0.7)
            }
        }

        /// Returns the workload level for a given load value
        static func forLoad(_ load: Double) -> WorkloadLevel {
            switch load {
            case ..<0.01: return .free
            case ..<0.4: return .light
            case ..<0.8: return .busy
            case ..<1.0: return .full
            default: return .over
            }
        }

        /// Returns a smooth gradient color based on exact load percentage
        static func gradientColor(for load: Double) -> Color {
            switch load {
            case ..<0.01:
                // Free - card background
                return DesignSystem.Colors.cardBackground
            case ..<0.8:
                // 0-80%: Accent color with opacity gradient from 0.15 to 0.55
                let normalizedLoad = load / 0.8  // 0 to 1
                let opacity = 0.15 + (normalizedLoad * 0.4)
                return DesignSystem.Colors.accent.opacity(opacity)
            case ..<1.0:
                // 80-100%: Transition from accent to warning
                let t = (load - 0.8) / 0.2  // 0 to 1
                let opacity = 0.5 + (t * 0.15)
                return DesignSystem.Colors.warning.opacity(opacity)
            default:
                // Over 100%: Error color, intensity increases with overload
                let overload = min(load - 1.0, 0.5)  // Cap at 150%
                let opacity = 0.5 + (overload * 0.5)
                return DesignSystem.Colors.error.opacity(opacity)
            }
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
            stones: Array(stones)
        )
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
    let touchCount: Int
    let dayLoad: Double  // 0.0 = empty, 1.0 = full, >1.0 = overloaded
    let hasDeadline: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if let day = dayData.day {
                    Spacer()

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

                    // DUE tag for deadline days
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
                    } else {
                        Color.clear
                            .frame(height: 14)
                    }

                    Spacer()
                        .frame(height: 4)
                } else {
                    Color.clear
                        .frame(height: 60)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(cellBackgroundColor)
            )
        }
        .buttonStyle(.plain)
    }

    /// Color based on workload - smooth gradient following the legend levels
    private var cellBackgroundColor: Color {
        if !dayData.isCurrentMonth {
            return Color.clear
        }

        // Use smooth gradient color based on exact load percentage
        return CalendarView.WorkloadLevel.gradientColor(for: dayLoad)
    }

    /// Color for deadline badges
    private var loadColor: Color {
        let level = CalendarView.WorkloadLevel.forLoad(dayLoad)
        switch level {
        case .over:
            return DesignSystem.Colors.error
        case .full:
            return DesignSystem.Colors.warning
        default:
            return DesignSystem.Colors.accent
        }
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
        .modelContainer(for: [StoneEvent.self, TouchLog.self, Project.self], inMemory: true)
}
