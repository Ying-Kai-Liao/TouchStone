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
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Month Header
                    monthNavigationHeader

                    // Calendar Grid
                    VStack(spacing: DesignSystem.Spacing.md) {
                        weekdayHeader
                        calendarGrid
                    }

                    // Energy Legend
                    energyLegend

                    Spacer(minLength: 100)
                }
                .padding(.top, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarHidden(true)
            .sheet(item: $selectedDay) { day in
                DayDetailView(
                    date: day.date,
                    stones: day.stones,
                    onAddStone: {
                        let dateToUse = day.date
                        selectedDay = nil
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

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                withAnimation {
                    selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(DesignSystem.Colors.cardBackground)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 4) {
                Text(monthYearFormatter.string(from: selectedMonth))
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("THE HORIZON")
                    .font(DesignSystem.Typography.captionBold)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.5)
            }

            Spacer()

            Button {
                withAnimation {
                    selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(DesignSystem.Colors.cardBackground)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var energyLegend: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("ENERGY GRADIENT")
                .sectionHeader()

            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(Array(zip(0..<5, ["STILL", "EASE", "FLOW", "POWER", "PEAK"])), id: \.0) { level, label in
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorForEnergyLevel(level))
                            .frame(width: 50, height: 40)

                        Text(label)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func colorForEnergyLevel(_ level: Int) -> Color {
        switch level {
        case 0: return DesignSystem.Colors.energyStill
        case 1: return DesignSystem.Colors.energyEase
        case 2: return DesignSystem.Colors.energyFlow
        case 3: return DesignSystem.Colors.energyPower
        default: return DesignSystem.Colors.energyPeak
        }
    }

    private var calendarGrid: some View {
        let days = generateCalendarDays()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
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
        .padding(.horizontal, DesignSystem.Spacing.lg)
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
            ZStack {
                // Background circle with energy color
                Circle()
                    .fill(cellBackgroundColor)
                    .frame(width: 40, height: 40)

                // Day number
                if let day = dayData.day {
                    Text("\(day)")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(isToday ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary)
                }

                // Deadline indicator
                if hasDeadline {
                    Circle()
                        .fill(DesignSystem.Colors.warning)
                        .frame(width: 6, height: 6)
                        .offset(y: 12)
                }

                // Stone indicator dots
                if !stones.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(stones.prefix(3)) { _ in
                            Circle()
                                .fill(DesignSystem.Colors.focus)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .offset(y: -14)
                }
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .disabled(dayData.day == nil)
    }

    /// Energy level based on load (0-4)
    private var energyLevel: Int {
        if dayLoad <= 0 { return 0 }
        if dayLoad < 0.25 { return 1 }
        if dayLoad < 0.5 { return 2 }
        if dayLoad < 0.75 { return 3 }
        return 4
    }

    private var cellBackgroundColor: Color {
        guard dayData.isCurrentMonth, dayData.day != nil else {
            return Color.clear
        }

        if isToday {
            return DesignSystem.Colors.accent
        }

        switch energyLevel {
        case 0: return DesignSystem.Colors.energyStill
        case 1: return DesignSystem.Colors.energyEase
        case 2: return DesignSystem.Colors.energyFlow
        case 3: return DesignSystem.Colors.energyPower
        default: return DesignSystem.Colors.energyPeak
        }
    }

    private var isToday: Bool {
        guard dayData.isCurrentMonth else { return false }
        return calendar.isDateInToday(dayData.date)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [StoneEvent.self, TouchLog.self, Project.self], inMemory: true)
}
