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
                VStack(spacing: 12) {
                    monthNavigationHeader
                    weekdayHeader
                    calendarGrid
                }
                .padding(.vertical, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMonth = Date()
                        }
                    } label: {
                        Text("Today")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
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
                SpeechStoneInputView(initialDate: addStoneDate)
            }
        }
    }

    private var monthNavigationHeader: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(monthYearFormatter.string(from: selectedMonth))
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var calendarGrid: some View {
        let days = generateCalendarDays()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
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
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
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
        return PressureCalculator.calculateDayLoad(for: date, projects: Array(activeProjects))
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
    private let accentColor = UserPreferences.shared.accentColor

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if let day = dayData.day {
                    Spacer()

                    // Day number - smaller
                    Text("\(day)")
                        .font(.system(size: 14, weight: isToday ? .bold : .medium))
                        .foregroundColor(dayData.isCurrentMonth ? .primary : Color.secondary.opacity(0.3))
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(isToday ? Color(.systemGray5) : Color.clear)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(isToday ? Color(.systemGray3) : Color.clear, lineWidth: 1.5)
                        )

                    Spacer()

                    // Event indicators (stone dots)
                    HStack(spacing: 3) {
                        if !stones.isEmpty {
                            ForEach(stones.prefix(3)) { _ in
                                Circle()
                                    .fill(Color(.systemGray3))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                    .frame(height: 6)

                    // DUE tag for deadline days
                    if hasDeadline {
                        Text("DUE")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(cellBackgroundColor)
            )
        }
        .buttonStyle(.plain)
    }

    /// Color based on load - accent color gradient
    private var loadColor: Color {
        if dayLoad > 1.0 {
            return .red  // Overloaded
        } else if dayLoad > 0.8 {
            return .orange  // Nearly full
        } else {
            return accentColor
        }
    }

    private var cellBackgroundColor: Color {
        if !dayData.isCurrentMonth {
            return Color.clear
        }

        // Show load-based color if there's any work allocated
        if dayLoad > 0 {
            // Opacity scales with load: 0.1 at 0% to 0.35 at 100%+
            let opacity = min(0.35, 0.1 + (dayLoad * 0.25))
            return loadColor.opacity(opacity)
        }

        if isWeekend {
            return Color(.systemGray6).opacity(0.4)
        }

        return Color(.systemGray6).opacity(0.25)
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
