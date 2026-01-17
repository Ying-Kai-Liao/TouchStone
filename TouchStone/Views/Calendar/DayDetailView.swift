import SwiftUI
import SwiftData

// MARK: - Chart Slice Data

struct ChartSlice: Identifiable {
    let id = UUID()
    let label: String
    let hours: Double
    let color: Color
    let isProject: Bool
}

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
                VStack(spacing: 16) {
                    // Date header
                    dateHeader

                    // Schedule section first (stones)
                    if !stones.isEmpty {
                        stonesSection
                    } else {
                        emptyScheduleHint
                    }

                    // Pie chart section
                    dayAllocationChart
                        .padding(.horizontal)
                }
                .padding(.bottom, 100)
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

    // MARK: - Pie Chart Data

    private var chartData: (slices: [ChartSlice], totalHours: Double, loadResult: PressureCalculator.DayLoadResult) {
        let dailyCapacityMinutes = prefs.dailyProductiveMinutes
        let loadResult = PressureCalculator.calculateDayLoadDetailed(
            for: date,
            projects: Array(activeProjects),
            stones: Array(allStones)
        )

        let stoneMinutes = dailyCapacityMinutes - loadResult.availableMinutes
        let totalHours = Double(dailyCapacityMinutes) / 60.0

        var slices: [ChartSlice] = []

        // Add stones (blocked time)
        if stoneMinutes > 0 {
            let stoneHours = roundToHalf(Double(stoneMinutes) / 60.0)
            slices.append(ChartSlice(
                label: "Stones",
                hours: stoneHours,
                color: .gray,
                isProject: false
            ))
        }

        // Add project allocations (rounded to nearest 0.5 hour)
        let projectColors: [Color] = [prefs.accentColor, .blue, .purple, .pink, .indigo, .cyan]
        for (index, allocation) in loadResult.projectAllocations.enumerated() {
            let hours = roundToHalf(allocation.allocatedMinutes / 60.0)
            if hours > 0 {
                slices.append(ChartSlice(
                    label: allocation.project.title,
                    hours: hours,
                    color: projectColors[index % projectColors.count],
                    isProject: true
                ))
            }
        }

        // Calculate free time
        let usedHours = slices.reduce(0.0) { $0 + $1.hours }
        let freeHours = max(0, totalHours - usedHours)
        if freeHours > 0 {
            slices.append(ChartSlice(
                label: "Free",
                hours: freeHours,
                color: Color(.systemGray5),
                isProject: false
            ))
        }

        return (slices, totalHours, loadResult)
    }

    private func roundToHalf(_ value: Double) -> Double {
        return (value * 2).rounded() / 2
    }

    // MARK: - Pie Chart View

    private var dayAllocationChart: some View {
        let data = chartData
        let loadPercent = Int(data.loadResult.load * 100)

        return VStack(spacing: 16) {
            // Header with day type badge
            HStack {
                Text("TIME ALLOCATION")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Spacer()

                if data.loadResult.isBufferDay {
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

            // Buffer warning if needed
            if data.loadResult.usedBufferDays {
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

            // Pie chart with center label
            ZStack {
                PieChartView(slices: data.slices, totalHours: data.totalHours)
                    .frame(width: 200, height: 200)

                // Center label
                VStack(spacing: 2) {
                    Text("\(loadPercent)%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(loadColor(for: data.loadResult.load))
                    Text("load")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(data.slices) { slice in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(slice.color)
                            .frame(width: 10, height: 10)
                        Text(slice.label)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(formatHours(slice.hours))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatHours(_ hours: Double) -> String {
        if hours == floor(hours) {
            return "\(Int(hours))h"
        } else {
            return String(format: "%.1fh", hours)
        }
    }

    // MARK: - Stones Section

    private var emptyScheduleHint: some View {
        VStack(spacing: 8) {
            Text("SCHEDULE")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(1)

            Text("No events scheduled")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var stonesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULE")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(1)
                .padding(.horizontal)

            ForEach(stones.sorted(by: { $0.startHour * 60 + $0.startMinute < $1.startHour * 60 + $1.startMinute })) { stone in
                SwipeToDeleteRow(
                    onDelete: {
                        stoneToDelete = stone
                        showDeleteAlert = true
                    }
                ) {
                    StoneRowView(stone: stone)
                }
                .padding(.horizontal)
            }
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

    private func loadColor(for load: Double) -> Color {
        if load > 1.0 {
            return .red
        } else if load > 0.8 {
            return .orange
        } else {
            return prefs.accentColor
        }
    }
}

// MARK: - Pie Chart View

struct PieChartView: View {
    let slices: [ChartSlice]
    let totalHours: Double

    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let innerRadius = radius * 0.6

            ZStack {
                // Draw slices
                ForEach(Array(sliceAngles.enumerated()), id: \.offset) { index, angles in
                    PieSlice(
                        startAngle: angles.start,
                        endAngle: angles.end,
                        innerRadius: innerRadius,
                        outerRadius: radius
                    )
                    .fill(slices[index].color)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var sliceAngles: [(start: Angle, end: Angle)] {
        var angles: [(start: Angle, end: Angle)] = []
        var currentAngle = Angle(degrees: -90) // Start from top

        for slice in slices {
            let sliceAngle = Angle(degrees: (slice.hours / totalHours) * 360)
            angles.append((start: currentAngle, end: currentAngle + sliceAngle))
            currentAngle = currentAngle + sliceAngle
        }

        return angles
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()

        // Start at inner radius
        let innerStart = CGPoint(
            x: center.x + innerRadius * cos(CGFloat(startAngle.radians)),
            y: center.y + innerRadius * sin(CGFloat(startAngle.radians))
        )
        path.move(to: innerStart)

        // Line to outer radius
        let outerStart = CGPoint(
            x: center.x + outerRadius * cos(CGFloat(startAngle.radians)),
            y: center.y + outerRadius * sin(CGFloat(startAngle.radians))
        )
        path.addLine(to: outerStart)

        // Arc along outer radius
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // Line to inner radius
        let innerEnd = CGPoint(
            x: center.x + innerRadius * cos(CGFloat(endAngle.radians)),
            y: center.y + innerRadius * sin(CGFloat(endAngle.radians))
        )
        path.addLine(to: innerEnd)

        // Arc along inner radius (clockwise to close)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Swipe to Delete Row

struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @GestureState private var dragOffset: CGFloat = 0
    @State private var currentOffset: CGFloat = 0
    @State private var isDeleting = false

    private let deleteButtonWidth: CGFloat = 70

    private var totalOffset: CGFloat {
        if isDeleting {
            return -500 // Slide far off screen
        }
        let raw = currentOffset + dragOffset
        // Rubber band effect when swiping right from closed state
        if raw > 0 {
            return raw * 0.3
        }
        // Rubber band effect when over-swiping left
        if raw < -deleteButtonWidth - 20 {
            let overshoot = raw + deleteButtonWidth + 20
            return -deleteButtonWidth - 20 + overshoot * 0.3
        }
        return raw
    }

    private var isOpen: Bool {
        currentOffset < -10
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button - always present but clipped
            HStack(spacing: 0) {
                Spacer()
                Button(action: {
                    // Animate row sliding out
                    withAnimation(.easeIn(duration: 0.25)) {
                        isDeleting = true
                    }
                    // Call onDelete after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: deleteButtonWidth, height: .infinity)
                }
                .frame(width: isDeleting ? 500 : max(0, -totalOffset), height: 70)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: isDeleting ? 0 : 12))
            }

            // Content
            content()
                .offset(x: totalOffset)
                .opacity(isDeleting ? 0 : 1)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .updating($dragOffset) { value, state, _ in
                            if !isDeleting {
                                state = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if isDeleting { return }
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            let projected = currentOffset + value.translation.width + velocity * 0.5

                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                if projected < -deleteButtonWidth / 2 {
                                    // Snap open
                                    currentOffset = -deleteButtonWidth
                                } else {
                                    // Snap closed
                                    currentOffset = 0
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            if isOpen && !isDeleting {
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                    currentOffset = 0
                                }
                            }
                        }
                )
        }
        .frame(height: isDeleting ? 0 : nil)
        .clipped()
        .animation(.easeIn(duration: 0.25), value: isDeleting)
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
