import SwiftUI
import SwiftData

struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Project> { $0.isActive }) private var activeProjects: [Project]
    @Query private var allStones: [StoneEvent]

    private var prefs: UserPreferences { UserPreferences.shared }

    @State private var stoneToDelete: StoneEvent?
    @State private var showDeleteAlert = false

    let date: Date
    let stones: [StoneEvent]
    let onAddStone: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Date header
                    dateHeader

                    Divider()

                    if stones.isEmpty {
                        emptyState
                    } else {
                        stonesList
                    }

                    // Pressure details section at bottom
                    pressureDetailsSection
                }
            }
            .safeAreaInset(edge: .bottom) {
                addStoneButton
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
            .alert("Delete Stone", isPresented: $showDeleteAlert, presenting: stoneToDelete) { stone in
                Button("Cancel", role: .cancel) {
                    stoneToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    deleteStone(stone)
                }
            } message: { stone in
                if stone.recurrence.type != .none {
                    Text("This is a recurring event. Deleting it will remove all occurrences of \"\(stone.title)\".")
                } else {
                    Text("Are you sure you want to delete \"\(stone.title)\"?")
                }
            }
        }
    }

    private func deleteStone(_ stone: StoneEvent) {
        modelContext.delete(stone)
        stoneToDelete = nil
    }

    private var dateHeader: some View {
        VStack(spacing: 8) {
            Text(formattedDate)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            if calendar.isDateInToday(date) {
                Text("Today")
                    .font(.subheadline)
                    .foregroundStyle(prefs.accentColor)
            } else if calendar.isDateInTomorrow(date) {
                Text("Tomorrow")
                    .font(.subheadline)
                    .foregroundStyle(prefs.accentColor)
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
        List {
            ForEach(stones.sorted(by: { $0.startHour * 60 + $0.startMinute < $1.startHour * 60 + $1.startMinute })) { stone in
                StoneRowView(stone: stone)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            stoneToDelete = stone
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
            .background(prefs.accentColor)
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

    // MARK: - Pressure Details

    private var pressureDetailsSection: some View {
        let dailyCapacity = UserPreferences.shared.dailyProductiveHours
        let dayPressure = PressureCalculator.calculateDayPressure(
            for: date,
            projects: Array(activeProjects),
            stones: Array(allStones),
            dailyCapacityHours: dailyCapacity
        )

        return Group {
            if dayPressure.projectPressures.isEmpty {
                VStack(spacing: 8) {
                    Text("PRESSURE ANALYSIS")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    Text("No projects with deadlines")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PRESSURE ANALYSIS")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    // Day capacity summary
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Daily capacity:")
                            Spacer()
                            Text("\(dailyCapacity) hrs (\(dayPressure.dailyCapacityMinutes) min)")
                        }
                        HStack {
                            Text("Stone time today:")
                            Spacer()
                            Text("\(dayPressure.stoneMinutes) min")
                                .foregroundStyle(dayPressure.stoneMinutes > 0 ? .orange : .primary)
                        }
                        HStack {
                            Text("Available capacity:")
                            Spacer()
                            Text("\(dayPressure.availableMinutes) min")
                                .foregroundStyle(dayPressure.availableMinutes < 60 ? .red : .primary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(.systemGray5).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    ForEach(dayPressure.projectPressures, id: \.project.id) { pp in
                        pressureCard(for: pp)
                    }

                    // Aggregate status
                    HStack {
                        Text("Day Status:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(dayPressure.worstPressure)%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(dayPressure.aggregateStatus.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(dayPressure.aggregateStatus.color == .clear ? .secondary : dayPressure.aggregateStatus.color)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
            }
        }
    }

    private func pressureCard(for pp: PressureCalculator.ProjectPressure) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pp.project.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(pp.pressure)%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(pp.status.color == .clear ? .secondary : pp.status.color)
                Circle()
                    .fill(pp.status.color == .clear ? Color.gray : pp.status.color)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Deadline:")
                    Spacer()
                    Text(deadlineFormatted(pp.deadline))
                        .foregroundStyle(pp.daysRemaining < 0 ? .red : .primary)
                }
                HStack {
                    Text("Days remaining:")
                    Spacer()
                    Text("\(pp.daysRemaining)")
                        .foregroundStyle(pp.daysRemaining <= 0 ? .red : .primary)
                }
                HStack {
                    Text("Work remaining:")
                    Spacer()
                    Text("\(pp.remainingMinutes / 60) hrs (\(pp.remainingMinutes) min)")
                }
                HStack {
                    Text("With 25% buffer:")
                    Spacer()
                    Text("\(pp.requiredMinutesWithBuffer) min")
                        .foregroundStyle(.orange)
                }
                HStack {
                    Text("Available capacity:")
                    Spacer()
                    Text("\(pp.availableCapacityMinutes) min")
                        .foregroundStyle(pp.availableCapacityMinutes < pp.requiredMinutesWithBuffer ? .red : .primary)
                }
                HStack {
                    Text("Status:")
                    Spacer()
                    Text(pp.status.displayName)
                        .fontWeight(.medium)
                        .foregroundStyle(pp.status.color == .clear ? .secondary : pp.status.color)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func deadlineFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
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
            .background(UserPreferences.shared.accentColor.opacity(0.1))
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
    @Previewable @State var stones: [StoneEvent] = []

    DayDetailView(
        date: Date(),
        stones: stones,
        onAddStone: {}
    )
    .modelContainer(for: [StoneEvent.self, Project.self], inMemory: true)
}
