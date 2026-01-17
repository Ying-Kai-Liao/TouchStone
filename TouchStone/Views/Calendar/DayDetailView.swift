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

    // MARK: - Load Details

    /// Projects with deadlines that include this day
    private var projectsWithDeadlines: [Project] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return activeProjects.filter { project in
            guard let deadline = project.deadline else { return false }
            let deadlineStart = calendar.startOfDay(for: deadline)
            return deadlineStart >= dayStart
        }
    }

    private var pressureDetailsSection: some View {
        let dailyCapacity = prefs.dailyProductiveMinutes
        let loadResult = PressureCalculator.calculateDayLoadDetailed(
            for: date,
            projects: Array(activeProjects),
            stones: Array(allStones)
        )
        let loadPercent = Int(loadResult.load * 100)
        let stoneMinutes = dailyCapacity - loadResult.availableMinutes

        return Group {
            if projectsWithDeadlines.isEmpty {
                VStack(spacing: 8) {
                    Text("DAY LOAD")
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
                    HStack {
                        Text("DAY LOAD")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        Spacer()

                        // Day type badge
                        if loadResult.isBufferDay {
                            Text("BUFFER DAY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        } else {
                            Text("WORK DAY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(prefs.accentColor)
                                .clipShape(Capsule())
                        }
                    }

                    // Buffer consumed warning
                    if loadResult.usedBufferDays {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Buffer days consumed due to high workload")
                                .font(.caption)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Day capacity summary
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Daily capacity:")
                            Spacer()
                            Text("\(dailyCapacity / 60) hrs (\(dailyCapacity) min)")
                        }
                        if stoneMinutes > 0 {
                            HStack {
                                Text("Stones (blocked):")
                                Spacer()
                                Text("-\(stoneMinutes) min")
                                    .foregroundStyle(.orange)
                            }
                        }
                        HStack {
                            Text("Available:")
                            Spacer()
                            Text("\(loadResult.availableMinutes / 60) hrs (\(loadResult.availableMinutes) min)")
                                .fontWeight(.medium)
                        }
                        Divider()
                        HStack {
                            Text("Allocated work:")
                            Spacer()
                            Text(formatDuration(Int(loadResult.allocatedMinutes)))
                        }
                        HStack {
                            Text("Day load:")
                            Spacer()
                            Text("\(loadPercent)%")
                                .fontWeight(.semibold)
                                .foregroundStyle(loadColor(for: loadResult.load))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(.systemGray5).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Project allocations
                    ForEach(loadResult.projectAllocations, id: \.project.id) { allocation in
                        loadCardDetailed(for: allocation)
                    }

                    // Overall status
                    HStack {
                        Text("Day Status:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(loadPercent)%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(loadColor(for: loadResult.load))
                        Text(loadStatusText(for: loadResult.load))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(loadColor(for: loadResult.load))
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
            }
        }
    }

    private func loadCard(for project: Project) -> some View {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let deadlineStart = calendar.startOfDay(for: project.deadline!)
        let daysRemaining = max(1, (calendar.dateComponents([.day], from: dayStart, to: deadlineStart).day ?? 0) + 1)
        let remainingMinutes = project.remainingHours * 60
        let dailyAllocation = remainingMinutes / daysRemaining

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(formatDuration(dailyAllocation))/day")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(prefs.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Deadline:")
                    Spacer()
                    Text(deadlineFormatted(project.deadline!))
                }
                HStack {
                    Text("Days remaining:")
                    Spacer()
                    Text("\(daysRemaining)")
                }
                HStack {
                    Text("Work remaining:")
                    Spacer()
                    Text("\(remainingMinutes / 60) hrs (\(remainingMinutes) min)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadCardDetailed(for allocation: PressureCalculator.DayLoadResult.ProjectAllocation) -> some View {
        let project = allocation.project
        let remainingMinutes = project.remainingHours * 60
        let bufferReduced = allocation.effectiveBufferDays < allocation.bufferDays

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()

                // Status badges
                if allocation.isOverloaded {
                    Text("OVERLOADED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                } else if allocation.isBufferDay {
                    Text("BUFFER")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                } else {
                    Text(formatDuration(Int(allocation.allocatedMinutes)))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(allocation.isOverloaded ? .red : prefs.accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Deadline:")
                    Spacer()
                    Text(deadlineFormatted(project.deadline!))
                }
                HStack {
                    Text("Work remaining:")
                    Spacer()
                    Text("\(remainingMinutes / 60) hrs (\(remainingMinutes) min)")
                }

                // Show buffer info with reduction warning if applicable
                HStack {
                    Text("Schedule:")
                    Spacer()
                    if bufferReduced {
                        Text("\(allocation.totalWorkDays) work + \(allocation.effectiveBufferDays) buffer")
                        Text("(\(allocation.bufferDays - allocation.effectiveBufferDays) used)")
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(allocation.totalWorkDays) work days + \(allocation.bufferDays) buffer")
                    }
                }

                if let dayIndex = allocation.workDayIndex {
                    HStack {
                        Text("This day:")
                        Spacer()
                        Text("Work day \(dayIndex + 1) of \(allocation.totalWorkDays)")
                            .foregroundStyle(allocation.isOverloaded ? .red : prefs.accentColor)
                    }
                } else {
                    HStack {
                        Text("This day:")
                        Spacer()
                        Text("Buffer (no work scheduled)")
                            .foregroundStyle(.orange)
                    }
                }

                // Overload warning
                if allocation.isOverloaded && !allocation.isBufferDay {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Cannot complete by deadline")
                            .foregroundStyle(.red)
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            allocation.isOverloaded ? Color.red.opacity(0.1) :
            allocation.isBufferDay ? Color.orange.opacity(0.1) :
            Color(.systemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadColor(for load: Double) -> Color {
        if load > 1.0 {
            return .red
        } else if load > 0.8 {
            return .orange
        } else {
            return prefs.accentColor
        }
    }

    private func loadStatusText(for load: Double) -> String {
        if load > 1.0 {
            return "Overloaded"
        } else if load > 0.8 {
            return "Busy"
        } else if load > 0.5 {
            return "Moderate"
        } else {
            return "Light"
        }
    }

    private func deadlineFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours) hrs \(mins) mins"
        } else if hours > 0 {
            return "\(hours) hrs"
        } else {
            return "\(mins) mins"
        }
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
