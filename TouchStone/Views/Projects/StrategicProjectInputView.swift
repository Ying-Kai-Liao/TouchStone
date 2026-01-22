import SwiftUI
import SwiftData

struct StrategicProjectInputView: View {
    @Environment(\.dismiss) private var dismiss

    private var prefs: UserPreferences { UserPreferences.shared }

    @State private var goal = ""
    @State private var isGenerating = false
    @State private var generatedPlan: StrategyEngine.PhasePlan?
    @State private var projectTitle = ""
    @State private var errorMessage: String?
    @State private var showReview = false

    private let strategyEngine = StrategyEngine()

    let onSave: (Project, [ProjectPhase]) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if generatedPlan == nil {
                    inputSection
                } else {
                    reviewSection
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle(generatedPlan == nil ? "Strategic Project" : "Review Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(prefs.accentColor)

                Text("What do you want to accomplish?")
                    .font(.title3)
                    .fontWeight(.medium)

                Text("Describe your goal and AI will break it into phases with time budgets")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextEditor(text: $goal)
                .frame(height: 120)
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if goal.isEmpty {
                        Text("e.g., Write a research paper on machine learning optimization techniques")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                generatePlan()
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGenerating ? "Analyzing..." : "Generate Plan")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(goal.isEmpty || isGenerating ? Color.gray : prefs.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(goal.isEmpty || isGenerating)
        }
    }

    // MARK: - Review Section

    @ViewBuilder
    private var reviewSection: some View {
        if let plan = generatedPlan {
            VStack(spacing: 16) {
                // Title input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Project title", text: $projectTitle)
                        .textFieldStyle(.roundedBorder)
                }

                // Archetype badge
                HStack {
                    if let archetype = Archetype(rawValue: plan.archetype.lowercased()) {
                        Label(archetype.displayName, systemImage: archetype.icon)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(prefs.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text("\(formatDuration(plan.totalEstimatedMinutes)) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Phases list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(plan.phases.enumerated()), id: \.offset) { index, phase in
                            PhaseReviewCard(phase: phase, index: index + 1)
                        }
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        generatedPlan = nil
                        projectTitle = ""
                    } label: {
                        Text("Regenerate")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        savePlan()
                    } label: {
                        Text("Looks Good")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(projectTitle.isEmpty ? Color.gray : prefs.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(projectTitle.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func generatePlan() {
        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let plan = try await strategyEngine.generatePhasePlan(for: goal)
                await MainActor.run {
                    generatedPlan = plan
                    // Default title from goal (first 50 chars)
                    projectTitle = String(goal.prefix(50))
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func savePlan() {
        guard let plan = generatedPlan else { return }

        let (project, phases) = strategyEngine.createPhaseProjectFromPlan(
            title: projectTitle,
            plan: plan
        )

        onSave(project, phases)
        dismiss()
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Phase Review Card

struct PhaseReviewCard: View {
    let phase: StrategyEngine.PhaseDetail
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Phase header
            HStack {
                Text("Phase \(index): \(phase.name)")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if let phaseType = PhaseType(rawValue: phase.type.lowercased()) {
                    Label(phaseType.displayName, systemImage: phaseType.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Mental rule
            Text("\"\(phase.mentalRule)\"")
                .font(.caption)
                .italic()
                .foregroundStyle(UserPreferences.shared.accentColor)

            // Time budget
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(phase.estimatedMinutes / 60) hours budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StrategicProjectInputView { _, _ in }
}
