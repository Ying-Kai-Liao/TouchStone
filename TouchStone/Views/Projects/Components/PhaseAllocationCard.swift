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

    var sessionCount: Int {
        max(1, phaseMinutes / 75) // ~75 min average session
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Phase name + type + time
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: phaseType.icon)
                        .foregroundStyle(Color.purple)
                    Text("\(index + 1). \(phaseName)")
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDuration(phaseMinutes))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("~\(sessionCount) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar with percentage
            HStack(spacing: 12) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorForPhaseType(phaseType))
                            .frame(width: geometry.size.width * CGFloat(percent) / 100, height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(percent)%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .frame(width: 45, alignment: .trailing)
            }

            // Adjustment controls
            HStack(spacing: 12) {
                Button {
                    onAdjust(-step)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(percent <= minPercent ? .secondary : .purple)
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
                .tint(colorForPhaseType(phaseType))

                Button {
                    onAdjust(step)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(percent >= maxPercent ? .secondary : .purple)
                }
                .disabled(percent >= maxPercent)
            }

            // Mental rule
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Color.purple.opacity(0.7))
                    .font(.caption)
                Text("\"\(mentalRule)\"")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Color.purple)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 {
            return "\(mins)m"
        } else if mins == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(mins)m"
        }
    }

    private func colorForPhaseType(_ type: PhaseType) -> Color {
        switch type {
        case .divergent: return .blue
        case .convergent: return .orange
        case .execution: return .green
        case .input: return .cyan
        case .output: return .purple
        case .reflection: return .pink
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
            mentalRule: "Hermit mode: no new inputs, just produce",
            index: 1,
            percent: .constant(50),
            totalMinutes: 2400,
            onAdjust: { _ in }
        )
    }
    .padding()
}
