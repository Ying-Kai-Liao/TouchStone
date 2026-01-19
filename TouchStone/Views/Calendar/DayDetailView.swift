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
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
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
                            .padding(.horizontal, DesignSystem.Spacing.xl)
                    }
                    .padding(.bottom, 100)
                }
                .safeAreaInset(edge: .bottom) {
                    addStoneButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
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
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text(formattedDate)
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            if calendar.isDateInToday(date) {
                Text("Today")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.accent)
            } else if calendar.isDateInTomorrow(date) {
                Text("Tomorrow")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            if !stones.isEmpty {
                Text("\(stones.count) event\(stones.count == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
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
                color: DesignSystem.Colors.textTertiary,
                isProject: false
            ))
        }

        // Add project allocations (rounded to nearest 0.5 hour)
        let projectColors: [Color] = [DesignSystem.Colors.accent, DesignSystem.Colors.focus, .purple, .pink, .indigo, .cyan]
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
                color: DesignSystem.Colors.cardBackground,
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

        return VStack(spacing: DesignSystem.Spacing.lg) {
            // Header with day type badge
            HStack {
                Text("TIME ALLOCATION")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1)

                Spacer()

                if data.loadResult.isBufferDay {
                    Text("BUFFER DAY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.background)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.warning)
                        .clipShape(Capsule())
                } else {
                    Text("WORK DAY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.background)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.accent)
                        .clipShape(Capsule())
                }
            }

            // Buffer warning if needed
            if data.loadResult.usedBufferDays {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DesignSystem.Colors.warning)
                    Text("Buffer days consumed due to high workload")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.warning.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
            }

            // Pie chart with center label
            ZStack {
                PieChartView(slices: data.slices, totalHours: data.totalHours)
                    .frame(width: 200, height: 200)

                // Center label
                VStack(spacing: 2) {
                    Text("\(loadPercent)%")
                        .font(DesignSystem.Typography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(loadColor(for: data.loadResult.load))
                    Text("load")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)

            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                ForEach(data.slices) { slice in
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Circle()
                            .fill(slice.color)
                            .frame(width: 8, height: 8)
                        Text(slice.label)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(formatHours(slice.hours))")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
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
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("SCHEDULE")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            Text("No events scheduled")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.lg)
    }

    private var stonesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("SCHEDULE")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xs)

            ForEach(stones.sorted(by: { $0.startHour * 60 + $0.startMinute < $1.startHour * 60 + $1.startMinute })) { stone in
                SwipeToDeleteRow(
                    onDelete: {
                        stoneToDelete = stone
                        showDeleteAlert = true
                    }
                ) {
                    StoneRowView(stone: stone)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
    }

    private var addStoneButton: some View {
        Button {
            onAddStone()
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                Text("Add Stone")
                    .font(DesignSystem.Typography.headline)
            }
            .foregroundStyle(DesignSystem.Colors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                    .fill(DesignSystem.Colors.accent)
            )
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.background)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    private func loadColor(for load: Double) -> Color {
        if load > 1.0 {
            return DesignSystem.Colors.error
        } else if load > 0.8 {
            return DesignSystem.Colors.warning
        } else {
            return DesignSystem.Colors.accent
        }
    }
}

// MARK: - Pie Chart View

struct PieChartView: View {
    let slices: [ChartSlice]
    let totalHours: Double

    // Gap between slices in degrees
    private let gapDegrees: Double = 2.5

    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let innerRadius = radius * 0.72  // Thinner donut

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

        let totalGap = gapDegrees * Double(slices.count)
        let availableDegrees = 360.0 - totalGap

        for slice in slices {
            let sliceAngle = Angle(degrees: (slice.hours / totalHours) * availableDegrees)
            let halfGap = Angle(degrees: gapDegrees / 2)
            angles.append((start: currentAngle + halfGap, end: currentAngle + sliceAngle + halfGap))
            currentAngle = currentAngle + sliceAngle + Angle(degrees: gapDegrees)
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

struct StoneRowView: View {
    let stone: StoneEvent

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(stone.startTimeString)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(stone.endTimeString)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .frame(width: 70, alignment: .leading)

            // Event card
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(stone.title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(stone.durationMinutes) min")
                        .font(DesignSystem.Typography.caption)

                    if stone.recurrence.type != .none {
                        Image(systemName: "repeat")
                            .font(.caption)
                        Text(recurrenceLabel)
                            .font(DesignSystem.Typography.caption)
                    }
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
            )
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
