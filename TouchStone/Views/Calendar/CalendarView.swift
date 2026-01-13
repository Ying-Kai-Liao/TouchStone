import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var stones: [StoneEvent]
    @Query private var touchLogs: [TouchLog]

    @State private var selectedMonth = Date()

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthNavigationHeader
                weekdayHeader
                calendarGrid
            }
            .navigationTitle("Calendar")
        }
    }

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Text(monthYearFormatter.string(from: selectedMonth))
                .font(.title2.bold())

            Spacer()

            Button {
                selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var calendarGrid: some View {
        let days = generateCalendarDays()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
            ForEach(days) { dayData in
                DayCell(
                    dayData: dayData,
                    stones: stonesForDay(dayData.date),
                    touchCount: touchCountForDay(dayData.date)
                )
            }
        }
        .padding(.horizontal)
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

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            if let day = dayData.day {
                Text("\(day)")
                    .font(.system(size: 16))
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(dayData.isCurrentMonth ? .primary : .tertiary)
                    .frame(height: 24)

                // Stone tags container
                VStack(spacing: 2) {
                    ForEach(stones.prefix(3)) { stone in
                        Text(stone.title)
                            .font(.system(size: 8))
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }

                    if stones.count > 3 {
                        Text("+\(stones.count - 3)")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 40, alignment: .top)

                // Touch indicator
                if touchCount > 0 {
                    HStack(spacing: 2) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                        Text("\(touchCount)")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Color.clear
                    .frame(height: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isToday ? Color.accentColor : Color.clear, lineWidth: 2)
        )
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
