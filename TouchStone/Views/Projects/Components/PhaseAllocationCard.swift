import SwiftUI

/// Card for displaying and adjusting a single phase's time allocation
struct PhaseAllocationCard: View {
    let phaseName: String
    let phaseType: PhaseType
    let mentalRule: String
    let index: Int
    @Binding var percent: Int
    let totalMinutes: Int
    let onAdjust: (Int) -> Void

    private let minPercent: Int = 5
    private let maxPercent: Int = 80
    private let step: Int = 5

    var phaseMinutes: Int {
        (totalMinutes * percent) / 100
    }

    var phaseHours: Int {
        phaseMinutes / 60
    }

    var sessionCount: Int {
        max(1, phaseMinutes / 75) // ~75 min average session
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header: Icon + Phase name + Mental rule | Hours + Sessions
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Phase icon in colored circle
                Image(systemName: phaseType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(colorForPhaseType(phaseType))
                    .frame(width: 36, height: 36)
                    .background(colorForPhaseType(phaseType).opacity(0.15))
                    .clipShape(Circle())

                // Phase name and mental rule
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(index + 1). \(phaseName)")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("\"\(mentalRule)\"")
                        .font(DesignSystem.Typography.caption)
                        .italic()
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // Hours and sessions
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(phaseHours)h")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("~\(sessionCount) SESSIONS")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .tracking(0.5)
                }
            }

            // Progress bar with percentage
            HStack(spacing: DesignSystem.Spacing.md) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DesignSystem.Colors.textTertiary.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForPhaseType(phaseType))
                            .frame(width: geometry.size.width * CGFloat(percent) / 100, height: 6)
                    }
                }
                .frame(height: 6)

                Text("\(percent)%")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(colorForPhaseType(phaseType))
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }

            // Adjustment controls: minus - slider - plus
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    onAdjust(-step)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(percent <= minPercent ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(DesignSystem.Colors.background)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(percent <= minPercent)

                Slider(
                    value: Binding(
                        get: { Double(percent) },
                        set: { newValue in
                            let newPercent = Int(newValue)
                            if newPercent != percent {
                                onAdjust(newPercent - percent)
                            }
                        }
                    ),
                    in: Double(minPercent)...Double(maxPercent),
                    step: Double(step)
                )
                .tint(DesignSystem.Colors.textTertiary)

                Button {
                    onAdjust(step)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(percent >= maxPercent ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(DesignSystem.Colors.background)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(percent >= maxPercent)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.15), lineWidth: 1)
        )
    }

    private func colorForPhaseType(_ type: PhaseType) -> Color {
        switch type {
        case .divergent: return Color(red: 0.4, green: 0.6, blue: 0.7)   // Teal blue
        case .convergent: return Color(red: 0.7, green: 0.5, blue: 0.3)  // Warm orange
        case .execution: return Color(red: 0.5, green: 0.65, blue: 0.5)  // Sage green
        case .input: return Color(red: 0.5, green: 0.6, blue: 0.7)       // Steel blue
        case .output: return Color(red: 0.65, green: 0.5, blue: 0.6)     // Dusty purple
        case .reflection: return Color(red: 0.7, green: 0.55, blue: 0.55) // Dusty rose
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PhaseAllocationCard(
            phaseName: "Exploration",
            phaseType: .divergent,
            mentalRule: "Explore widely, no conclusions yet",
            index: 0,
            percent: .constant(25),
            totalMinutes: 2400,
            onAdjust: { _ in }
        )

        PhaseAllocationCard(
            phaseName: "Bricklaying",
            phaseType: .execution,
            mentalRule: "Hermit mode: just produce",
            index: 1,
            percent: .constant(50),
            totalMinutes: 2400,
            onAdjust: { _ in }
        )

        PhaseAllocationCard(
            phaseName: "Refining",
            phaseType: .convergent,
            mentalRule: "No new research, only polish",
            index: 2,
            percent: .constant(25),
            totalMinutes: 2400,
            onAdjust: { _ in }
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
