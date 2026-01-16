import SwiftUI

/// Displays generated sessions grouped by phase for review
struct SessionGoalsList: View {
    let phases: [StrategyChatEngine.PhasePlan]
    let phaseStructure: [PhaseTemplate]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phasePlan in
                phaseSection(phasePlan: phasePlan, index: index)
            }
        }
    }

    @ViewBuilder
    private func phaseSection(phasePlan: StrategyChatEngine.PhasePlan, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Phase header
            HStack {
                if index < phaseStructure.count {
                    Image(systemName: phaseStructure[index].type.icon)
                        .foregroundStyle(UserPreferences.shared.accentColor)
                }
                Text("Phase \(index + 1): \(phasePlan.name)")
                    .font(.headline)

                Spacer()

                Text("\(phasePlan.sessions.count) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Sessions list
            VStack(spacing: 8) {
                ForEach(Array(phasePlan.sessions.enumerated()), id: \.offset) { sessionIndex, session in
                    sessionRow(session: session, index: sessionIndex)
                }
            }
        }
    }

    private func sessionRow(session: StrategyChatEngine.SessionPlan, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Session number
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(UserPreferences.shared.accentColor.opacity(0.7))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(formatDuration(session.estimatedMinutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(session.goal)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "~\(minutes)m"
        } else if minutes == 60 {
            return "~1h"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "~\(hours)h \(mins)m" : "~\(hours)h"
        }
    }
}

#Preview {
    ScrollView {
        SessionGoalsList(
            phases: StrategyChatEngine.mockSessions().phases,
            phaseStructure: Archetype.lab.phaseStructure
        )
        .padding()
    }
}
