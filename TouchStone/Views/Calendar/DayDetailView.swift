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
    @Query private var allContexts: [DayContext]

    private var prefs: UserPreferences { UserPreferences.shared }

    // Contexts active for this specific date
    private var activeContexts: [DayContext] {
        allContexts.filter { $0.appliesTo(date: date) }
    }

    @State private var stoneToDelete: StoneEvent?
    @State private var showDeleteAlert = false
    @State private var stoneToEdit: StoneEvent?
    @State private var contextToDelete: DayContext?
    @State private var showDeleteContextAlert = false
    @State private var contextToEdit: DayContext?
    @State private var dayState: DayState?
    @State private var showTimeAllocation = false
    @State private var showingAddContext = false

    let date: Date
    let stones: [StoneEvent]
    let onAddStone: () -> Void

    private let calendar = Calendar.current

    // Computed suggested sessions for this day
    private var suggestedSessions: [SuggestedSession] {
        dayState?.suggestedSessions ?? []
    }

    // Context-aware work suppression
    private var shouldSuppressWork: Bool {
        let mode = activeContexts.strictestWorkMode(for: date)
        return mode == .none || mode == .fixed
    }

    // Fixed task description if in fixed mode
    private var fixedTaskDescription: String? {
        activeContexts.fixedTask(for: date)
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
                .alert("Delete Stone", isPresented: $showDeleteAlert, presenting: stoneToDelete) { stone in
                    Button("Cancel", role: .cancel) { stoneToDelete = nil }
                    Button("Delete", role: .destructive) { deleteStone(stone) }
                } message: { stone in
                    Text(stone.recurrence.type != .none
                         ? "This is a recurring event. Deleting it will remove all occurrences of \"\(stone.title)\"."
                         : "Are you sure you want to delete \"\(stone.title)\"?")
                }
                .alert("Delete Day Plan", isPresented: $showDeleteContextAlert, presenting: contextToDelete) { context in
                    Button("Cancel", role: .cancel) { contextToDelete = nil }
                    Button("Delete", role: .destructive) { deleteContext(context) }
                } message: { context in
                    Text(context.durationDays > 1
                         ? "This day plan spans \(context.durationDays) days. Deleting it will remove \"\(context.name)\" from all those days."
                         : "Are you sure you want to delete \"\(context.name)\"?")
                }
                .sheet(item: $stoneToEdit) { stone in
                    StoneEditSheet(stone: stone, onSave: {})
                }
                .sheet(isPresented: $showingAddContext) {
                    NavigationStack { ContextFormView(context: nil, initialDate: date) }
                }
                .sheet(item: $contextToEdit) { context in
                    NavigationStack { ContextFormView(context: context, initialDate: date) }
                }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    private var mainContent: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                scrollContent
            }
            .onAppear { computeDayState() }
            .safeAreaInset(edge: .bottom) { addStoneButton }
        }
    }

    private var scrollContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            dateHeader

            if !activeContexts.isEmpty {
                contextBanner
            }

            if !stones.isEmpty {
                stonesSection
            } else {
                emptyScheduleHint
            }

            if !suggestedSessions.isEmpty && !shouldSuppressWork {
                suggestedWorkSection
            } else if shouldSuppressWork && !activeContexts.isEmpty {
                noWorkMessage
            }

            if let fixedTask = fixedTaskDescription {
                fixedTaskSection(task: fixedTask)
            }

            timeAllocationSection
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .padding(.bottom, 100)
    }

    private func deleteStone(_ stone: StoneEvent) {
        modelContext.delete(stone)
        stoneToDelete = nil
    }

    private func deleteContext(_ context: DayContext) {
        modelContext.delete(context)
        contextToDelete = nil
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

    // MARK: - Compute Day State

    private func computeDayState() {
        let state = DayState(date: date)
        state.compute(
            stones: Array(allStones),
            projects: Array(activeProjects),
            contexts: Array(allContexts)
        )
        dayState = state
    }

    // MARK: - Suggested Work Section

    private var suggestedWorkSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("SUGGESTED WORK")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            ForEach(suggestedSessions) { session in
                SuggestedWorkRow(session: session)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.xl)
    }

    // MARK: - Time Allocation Section (Collapsible)

    private var timeAllocationSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTimeAllocation.toggle()
                }
            } label: {
                HStack {
                    Text("TIME ALLOCATION")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .tracking(1)

                    Spacer()

                    Image(systemName: showTimeAllocation ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
            .buttonStyle(.plain)

            if showTimeAllocation {
                dayAllocationChart
                    .padding(.top, DesignSystem.Spacing.sm)
            }
        }
    }

    // MARK: - Pie Chart Data

    private var chartData: (slices: [ChartSlice], totalHours: Double, loadResult: PressureCalculator.DayLoadResult) {
        let dailyCapacityMinutes = prefs.dailyProductiveMinutes
        let loadResult = PressureCalculator.calculateDayLoadDetailed(
            for: date,
            projects: Array(activeProjects),
            stones: Array(allStones),
            contexts: Array(allContexts)
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
        // Use accent color with varying opacities for monochromatic design
        let projectCount = loadResult.projectAllocations.count
        for (index, allocation) in loadResult.projectAllocations.enumerated() {
            let hours = roundToHalf(allocation.allocatedMinutes / 60.0)
            if hours > 0 {
                // Opacity ranges from 1.0 (first project) down to 0.4 (last project)
                let opacity = projectCount > 1 ? 1.0 - (Double(index) * 0.6 / Double(projectCount - 1)) : 1.0
                slices.append(ChartSlice(
                    label: allocation.project.title,
                    hours: hours,
                    color: DesignSystem.Colors.accent.opacity(opacity),
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
            // Day type badge
            HStack {
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

            ForEach(stones.sorted(by: { $0.startHour * 60 + $0.startMinute < $1.startHour * 60 + $1.startMinute })) { stone in
                SwipeToDeleteRow(
                    onDelete: {
                        stoneToDelete = stone
                        showDeleteAlert = true
                    }
                ) {
                    StoneRowView(stone: stone)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            stoneToEdit = stone
                        }
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
        .padding(.bottom, DesignSystem.Spacing.xl)
    }

    private var addStoneButton: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Add Event button
            Button {
                onAddStone()
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add Event")
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

            // Day Plan button
            Button {
                showingAddContext = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 18))
                    Text("Day Plan")
                        .font(DesignSystem.Typography.headline)
                }
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.accent, lineWidth: 2)
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Context Banner

    private var contextBanner: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(activeContexts) { context in
                SwipeToDeleteRow(
                    onDelete: {
                        contextToDelete = context
                        showDeleteContextAlert = true
                    }
                ) {
                    ContextBannerRow(context: context)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            contextToEdit = context
                        }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }

    // MARK: - No Work Message

    private var noWorkMessage: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 32))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("Day Off")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("No work sessions scheduled for this day.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
    }

    // MARK: - Fixed Task Section

    private func fixedTaskSection(task: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("TODAY'S FOCUS")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignSystem.Colors.accent)

                Text(task)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
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

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth: CGFloat = size * 0.13  // Donut thickness
            let radius = (size - lineWidth) / 2

            // Calculate cap extension as fraction of circle
            // Round caps extend by lineWidth/2 at each end
            let capExtension = (lineWidth / 2) / (2 * .pi * radius)

            // Gap between segments (visual gap after accounting for caps)
            let visualGapDegrees: CGFloat = 4.0
            let gapFraction = visualGapDegrees / 360.0

            ZStack {
                ForEach(Array(computeSliceAngles(capExtension: capExtension, gapFraction: gapFraction).enumerated()), id: \.offset) { index, angles in
                    Circle()
                        .trim(from: angles.start, to: angles.end)
                        .stroke(
                            slices[index].color,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: radius * 2, height: radius * 2)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func computeSliceAngles(capExtension: CGFloat, gapFraction: CGFloat) -> [(start: CGFloat, end: CGFloat)] {
        var angles: [(start: CGFloat, end: CGFloat)] = []
        var currentPosition: CGFloat = 0

        // Total space needed for gaps and cap extensions
        let totalCapSpace = capExtension * 2 * CGFloat(slices.count)  // Each segment has 2 caps
        let totalGapSpace = gapFraction * CGFloat(slices.count)
        let availableFraction = max(0, 1.0 - totalGapSpace - totalCapSpace)

        for slice in slices {
            let sliceFraction = CGFloat(slice.hours / totalHours) * availableFraction

            // Start after gap and account for the start cap
            let startPos = currentPosition + gapFraction / 2 + capExtension
            // End before the next gap, accounting for end cap
            let endPos = startPos + sliceFraction

            if sliceFraction > 0.001 {  // Only add visible slices
                angles.append((start: startPos, end: endPos))
            }

            currentPosition += sliceFraction + gapFraction + capExtension * 2
        }

        return angles
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

// MARK: - Suggested Work Row

struct SuggestedWorkRow: View {
    let session: SuggestedSession
    private let prefs = UserPreferences.shared

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(session.periodLabel)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text("~\(session.suggestedMinutes)m")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(width: 70, alignment: .leading)

            // Project card
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(session.project.title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                // Phase name
                if let phase = session.project.activePhase {
                    Text(phase.title)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(prefs.accentColor)
                } else if let phase = session.project.currentPhase {
                    Text(phase)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
            )
        }
    }
}

// MARK: - Context Banner Row

struct ContextBannerRow: View {
    let context: DayContext

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: context.type.icon)
                .font(.system(size: 18))
                .foregroundStyle(DesignSystem.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(context.shortDescription)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Work mode indicator
            Text(context.workMode.displayName.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(context.workMode.color)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    Capsule()
                        .fill(context.workMode.color.opacity(0.15))
                )
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                .fill(DesignSystem.Colors.accent.opacity(0.1))
        )
    }
}

#Preview {
    @Previewable @State var stones: [StoneEvent] = []

    DayDetailView(
        date: Date(),
        stones: stones,
        onAddStone: {}
    )
    .modelContainer(for: [StoneEvent.self, Project.self, DayContext.self], inMemory: true)
}
