import SwiftUI
import SwiftData

struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let stones: [StoneEvent]
    let onAddStone: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date header
                dateHeader

                Divider()

                if stones.isEmpty {
                    emptyState
                } else {
                    stonesList
                }

                Spacer()
            }
            .navigationTitle("Day Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                addStoneButton
            }
        }
    }

    private var dateHeader: some View {
        VStack(spacing: 8) {
            Text(formattedDate)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            if calendar.isDateInToday(date) {
                Text("Today")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            } else if calendar.isDateInTomorrow(date) {
                Text("Tomorrow")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }

            if !stones.isEmpty {
                Text("\(stones.count) event\(stones.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .padding(.top, 60)

            Text("No events scheduled")
                .font(.title3)
                .fontWeight(.medium)

            Text("Tap the button below to add your first event")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stonesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(stones.sorted(by: { $0.startHour * 60 + $0.startMinute < $1.startHour * 60 + $1.startMinute })) { stone in
                    StoneRowView(stone: stone)
                }
            }
            .padding()
        }
    }

    private var addStoneButton: some View {
        Button {
            onAddStone()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.title3)
                Text("Add Stone")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .background(.regularMaterial)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
}

struct StoneRowView: View {
    let stone: StoneEvent

    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(stone.startTimeString)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(stone.endTimeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 70, alignment: .leading)

            // Event card
            VStack(alignment: .leading, spacing: 6) {
                Text(stone.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(stone.durationMinutes) min")
                        .font(.caption)

                    if stone.recurrence.type != .none {
                        Image(systemName: "repeat")
                            .font(.caption)
                        Text(recurrenceLabel)
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var recurrenceLabel: String {
        switch stone.recurrence.type {
        case .none: return "One time"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .weekly: return "Weekly"
        case .custom:
            if let days = stone.recurrence.customDays {
                let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                return days.map { dayLabels[$0 - 1] }.joined(separator: ", ")
            }
            return "Custom"
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: StoneEvent.self, configurations: config)

    let stone1 = StoneEvent(
        title: "Morning Meeting",
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
        specificDate: Date(),
        recurrence: .none
    )

    let stone2 = StoneEvent(
        title: "Lunch",
        startHour: 12,
        startMinute: 0,
        endHour: 13,
        endMinute: 0,
        specificDate: nil,
        recurrence: .daily
    )

    container.mainContext.insert(stone1)
    container.mainContext.insert(stone2)

    return DayDetailView(
        date: Date(),
        stones: [stone1, stone2],
        onAddStone: {}
    )
    .modelContainer(container)
}
