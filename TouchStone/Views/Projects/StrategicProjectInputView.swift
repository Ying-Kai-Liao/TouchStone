import SwiftUI
import SwiftData

struct StrategicProjectInputView: View {
    @Environment(\.dismiss) private var dismiss

    private var prefs: UserPreferences { UserPreferences.shared }

    @State private var goal = ""
    @State private var isGenerating = false
    @State private var generatedPlan: StrategyEngine.StrategyPlan?
    @State private var projectTitle = ""
    @State private var errorMessage: String?
    @State private var showReview = false

    private let strategyEngine = StrategyEngine()

    let onSave: (Project, [ProjectPhase]) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                if generatedPlan == nil {
                    inputSection
                } else {
                    reviewSection
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
            .navigationTitle(generatedPlan == nil ? "Strategic Project" : "Review Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(DesignSystem.Colors.accent)

                Text("What do you want to accomplish?")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Describe your goal and AI will break it into phases and sessions")
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            TextEditor(text: $goal)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(height: 120)
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if goal.isEmpty {
                        Text("e.g., Write a research paper on machine learning optimization techniques")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.lg)
                            .allowsHitTesting(false)
                    }
                }

            if let error = errorMessage {
                Text(error)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.error)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                generatePlan()
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .tint(DesignSystem.Colors.background)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGenerating ? "Analyzing..." : "Generate Plan")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.lg)
                .background(goal.isEmpty || isGenerating ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent)
                .foregroundStyle(DesignSystem.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
            .disabled(goal.isEmpty || isGenerating)
        }
    }

    // MARK: - Review Section

    @ViewBuilder
    private var reviewSection: some View {
        if let plan = generatedPlan {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Title input
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Project Title")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    TextField("Project title", text: $projectTitle)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
                        )
                }

                // Archetype badge
                HStack {
                    if let archetype = Archetype(rawValue: plan.archetype.lowercased()) {
                        Label(archetype.displayName, systemImage: archetype.icon)
                            .font(DesignSystem.Typography.caption)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(DesignSystem.Colors.accent.opacity(0.15))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text("\(formatDuration(plan.totalEstimatedMinutes)) total")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                // Phases list
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(Array(plan.phases.enumerated()), id: \.offset) { index, phase in
                            PhaseReviewCard(phase: phase, index: index + 1)
                        }
                    }
                }

                // Action buttons
                HStack(spacing: DesignSystem.Spacing.md) {
                    Button {
                        generatedPlan = nil
                        projectTitle = ""
                    } label: {
                        Text("Regenerate")
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.lg)
                            .background(DesignSystem.Colors.cardBackground)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    Button {
                        savePlan()
                    } label: {
                        Text("Looks Good")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.lg)
                            .background(projectTitle.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent)
                            .foregroundStyle(DesignSystem.Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
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
                let plan = try await strategyEngine.generatePlan(for: goal)
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

        let (project, phases) = strategyEngine.createProjectFromPlan(
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
    let phase: StrategyEngine.PhasePlan
    let index: Int

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Phase header
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Phase \(index): \(phase.name)")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Spacer()

                    if let phaseType = PhaseType(rawValue: phase.type.lowercased()) {
                        Label(phaseType.displayName, systemImage: phaseType.icon)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }

            // Mental rule
            Text("\"\(phase.mentalRule)\"")
                .font(DesignSystem.Typography.caption)
                .italic()
                .foregroundStyle(DesignSystem.Colors.accent)

            // Sessions
            if isExpanded {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(phase.sessions.enumerated()), id: \.offset) { _, session in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "circle")
                                .font(.caption2)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .padding(.top, DesignSystem.Spacing.xs)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(session.title)
                                        .font(DesignSystem.Typography.callout)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Spacer()
                                    Text("~\(session.estimatedMinutes)m")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                                Text(session.goal)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.leading, DesignSystem.Spacing.sm)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    StrategicProjectInputView { _, _ in }
}
