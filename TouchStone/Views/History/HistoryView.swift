import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \TouchLog.timestamp, order: .reverse) private var touchLogs: [TouchLog]

    var body: some View {
        NavigationStack {
            Group {
                if touchLogs.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
        }
    }

    private var historyList: some View {
        List {
            ForEach(groupedLogs, id: \.date) { group in
                Section {
                    ForEach(group.logs) { log in
                        HistoryLogRow(log: log)
                    }
                } header: {
                    HStack {
                        Text(formatDateHeader(group.date))
                        Spacer()
                        Text("\(group.logs.count) touches")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No History", systemImage: "calendar")
        } description: {
            Text("Your touch logs will appear here.\nStart by touching a project!")
        }
    }

    private var groupedLogs: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: touchLogs) { log in
            calendar.startOfDay(for: log.timestamp)
        }
        return grouped.map { DayGroup(date: $0.key, logs: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

private struct DayGroup {
    let date: Date
    let logs: [TouchLog]
}

struct HistoryLogRow: View {
    let log: TouchLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.projectTitle)
                    .fontWeight(.medium)

                Spacer()

                Text(log.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(log.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if let note = log.note, !note.isEmpty {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [TouchLog.self, Project.self], inMemory: true)
}
