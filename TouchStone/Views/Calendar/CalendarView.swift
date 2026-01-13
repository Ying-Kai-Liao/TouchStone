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
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

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
                StoneEventFormView(onSave: { stone in
                    modelContext.insert(stone)
                }, initialDate: selectedDate)
            }
        }
    }

    private var monthNavigationHeader: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
            }

            Spacer()

            Text(monthYearFormatter.string(from: selectedMonth))
                .font(.title.bold())
                .foregroundStyle(.primary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var calendarGrid: some View {
        let days = generateCalendarDays()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 10) {
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
            VStack(spacing: 4) {
                if let day = dayData.day {
                    // Day number
                    Text("\(day)")
                        .font(.system(size: 18, weight: isToday ? .bold : .semibold))
                        .foregroundStyle(isToday ? .white : (dayData.isCurrentMonth ? .primary : .tertiary))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(isToday ? Color.accentColor : Color.clear)
                        )
                        .padding(.top, 4)

                    // Stone tags container
                    VStack(spacing: 2) {
                        ForEach(stones.prefix(2)) { stone in
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 4, height: 4)
                                Text(stone.title)
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.15))
                            )
                            .foregroundStyle(.blue)
                        }

                        if stones.count > 2 {
                            Text("+\(stones.count - 2) more")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.top, 1)
                        }
                    }
                    .frame(height: 45, alignment: .top)

                    Spacer(minLength: 0)

                    // Touch indicator
                    if touchCount > 0 {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                            Text("\(touchCount)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                        .padding(.bottom, 4)
                    }
                } else {
                    Color.clear
                        .frame(height: 100)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(dayData.isCurrentMonth ? (isWeekend ? Color(.systemGray6) : Color(.systemBackground)) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isToday ? Color.accentColor : Color(.systemGray4), lineWidth: isToday ? 2.5 : (dayData.isCurrentMonth ? 1 : 0))
            )
        }
        .buttonStyle(.plain)
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
