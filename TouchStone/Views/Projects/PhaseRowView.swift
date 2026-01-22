import SwiftUI
import SwiftData

/// Displays a phase with time budget progress (replaces session list).
/// Shows phase title, mental rule, and time invested vs budget.
struct PhaseRowView: View {
    let phase: ProjectPhase
    var isExpanded: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                // Phase type icon
                Image(systemName: phase.phaseType.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(phaseColor)
                    .frame(width: 24)

                // Title and type
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.title)
                        .font(.headline)

                    Text(phase.phaseType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Progress indicator
                VStack(alignment: .trailing, spacing: 2) {
                    Text(phase.progressString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(progressColor)

                    if phase.isComplete {
                        Text("Complete")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }

            // Progress bar
            ProgressView(value: phase.progress)
                .tint(progressColor)

            // Mental rule (if expanded or always shown)
            if let mentalRule = phase.mentalRule, !mentalRule.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(mentalRule)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private var phaseColor: Color {
        switch phase.phaseType {
        case .divergent: return .blue
        case .convergent: return .purple
        case .execution: return .orange
        case .input: return .green
        case .output: return .red
        case .reflection: return .teal
        }
    }

    private var progressColor: Color {
        if phase.isComplete {
            return .green
        } else if phase.progress > 0.7 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Compact Phase Row

/// A more compact phase row for summary views
struct CompactPhaseRow: View {
    let phase: ProjectPhase

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: phase.phaseType.icon)
                .font(.system(size: 14))
                .foregroundStyle(phase.isComplete ? .green : .secondary)
                .frame(width: 20)

            Text(phase.title)
                .font(.subheadline)
                .foregroundStyle(phase.isComplete ? .secondary : .primary)

            Spacer()

            Text(phase.formattedEstimate)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Progress circle
            Circle()
                .trim(from: 0, to: phase.progress)
                .stroke(phase.isComplete ? Color.green : Color.blue, lineWidth: 2)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(-90))
                .overlay {
                    if phase.isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Active Phase Card

/// A highlighted card for the currently active phase
struct ActivePhaseCard: View {
    let phase: ProjectPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: phase.phaseType.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Phase")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(phase.title)
                        .font(.headline)
                }

                Spacer()

                Text(phase.progressString)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }

            if let mentalRule = phase.mentalRule, !mentalRule.isEmpty {
                Text(mentalRule)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            ProgressView(value: phase.progress)
                .tint(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Preview

#Preview("Phase Row View") {
    VStack(spacing: 16) {
        PhaseRowView(phase: {
            let p = ProjectPhase(
                title: "Research",
                phaseType: .divergent,
                mentalRule: "Explore widely, no conclusions yet",
                sequenceOrder: 0,
                estimatedMinutes: 180
            )
            return p
        }())

        Divider()

        CompactPhaseRow(phase: ProjectPhase(
            title: "Draft",
            phaseType: .execution,
            mentalRule: "Write fast, don't edit",
            sequenceOrder: 1,
            estimatedMinutes: 300
        ))

        Divider()

        ActivePhaseCard(phase: ProjectPhase(
            title: "Polish",
            phaseType: .convergent,
            mentalRule: "Refine and perfect",
            sequenceOrder: 2,
            estimatedMinutes: 120
        ))
    }
    .padding()
}
