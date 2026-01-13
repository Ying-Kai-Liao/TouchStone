import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stones: [StoneEvent]
    @Query private var touchLogs: [TouchLog]

    @State private var selectedMonth = Date()
    @State private var showingAddStone = false
    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthNavigationHeader
                    weekdayHeader
                    calendarGrid
                }
                .padding(.vertical)
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMonth = Date()
                        }
                    } label: {
                        Text("Today")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingAddStone) {
                SpeechStoneInputView(initialDate: selectedDate)
            }
        }
    }

    private var monthNavigationHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(monthYearFormatter.string(from: selectedMonth))
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text("CALENDAR VIEW")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .tracking(1.2)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var calendarGrid: some View {
        let days = generateCalendarDays()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
            ForEach(days) { dayData in
                DayCell(
                    dayData: dayData,
                    stones: stonesForDay(dayData.date),
                    touchCount: touchCountForDay(dayData.date),
                    onTap: {
                        if dayData.isCurrentMonth {
                            selectedDate = dayData.date
                            showingAddStone = true
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
            stone.isActive && stone.occursOn(date: date)
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
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                if let day = dayData.day {
                    Spacer()

                    // Day number
                    Text("\(day)")
                        .font(.system(size: 20, weight: isToday ? .bold : .semibold))
                        .foregroundStyle(isToday ? .white : (dayData.isCurrentMonth ? .primary : .secondary.opacity(0.3)))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isToday ? Color.accentColor : Color.clear)
                        )

                    Spacer()

                    // Event indicators
                    HStack(spacing: 4) {
                        if !stones.isEmpty {
                            ForEach(stones.prefix(3)) { _ in
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .frame(height: 12)
                    .padding(.bottom, 8)
                } else {
                    Color.clear
                        .frame(height: 80)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cellBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isToday ? Color.accentColor : Color.clear, lineWidth: isToday ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private var cellBackgroundColor: Color {
        if !dayData.isCurrentMonth {
            return Color.clear
        }

        if isWeekend {
            return Color(.systemGray6).opacity(0.5)
        }

        return Color(.systemGray6).opacity(0.3)
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
