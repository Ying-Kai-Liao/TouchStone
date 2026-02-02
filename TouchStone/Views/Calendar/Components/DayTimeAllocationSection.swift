import SwiftUI

// MARK: - Day Time Allocation Section

/// A collapsible section that displays the time allocation pie chart for a day.
/// Shows:
/// - Day type badge (WORK DAY / BUFFER DAY)
/// - Buffer warning if buffer days were consumed
/// - Donut pie chart with load percentage center label
/// - Legend with hours for each slice
struct DayTimeAllocationSection: View {
    let date: Date
    let projects: [Project]
    let stones: [StoneEvent]
    let contexts: [DayContext]

    @Binding var isExpanded: Bool

    private var prefs: UserPreferences { UserPreferences.shared }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsible header button
            Button {
                HapticService.lightTap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("TIME ALLOCATION")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .tracking(1)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
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

            if isExpanded {
                dayAllocationChart
                    .padding(.top, DesignSystem.Spacing.sm)
            }
        }
    }

    // MARK: - Chart Data

    private var chartData: (slices: [ChartSlice], totalHours: Double, loadResult: PressureCalculator.DayLoadResult) {
        let dailyCapacityMinutes = prefs.dailyProductiveMinutes
        let loadResult = PressureCalculator.calculateDayLoadDetailed(
            for: date,
            projects: projects,
            stones: stones,
            contexts: contexts
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

    // MARK: - Helper Functions

    private func formatHours(_ hours: Double) -> String {
        if hours == floor(hours) {
            return "\(Int(hours))h"
        } else {
            return String(format: "%.1fh", hours)
        }
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

    private func roundToHalf(_ value: Double) -> Double {
        return (value * 2).rounded() / 2
    }
}

// MARK: - Pie Chart View

/// A donut-style pie chart visualization for time allocation.
/// Uses rounded stroke caps with gaps between segments.
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

// MARK: - Preview

#Preview {
    @Previewable @State var isExpanded = true

    ScrollView {
        DayTimeAllocationSection(
            date: Date(),
            projects: [],
            stones: [],
            contexts: [],
            isExpanded: $isExpanded
        )
        .padding(DesignSystem.Spacing.xl)
    }
    .background(DesignSystem.Colors.background)
}
