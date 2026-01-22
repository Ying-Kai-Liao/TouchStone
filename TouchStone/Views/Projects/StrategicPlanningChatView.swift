import SwiftUI
import SwiftData

/// Chat-based strategic planning flow with dual-mode support (phase or milestone)
struct StrategicPlanningChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var prefs: UserPreferences { UserPreferences.shared }

    @State private var step: StrategyChatEngine.ChatStep = .idle
    @State private var goal = ""
    @State private var projectTitle = ""
    @State private var projectMode: ProjectMode = .phase
    @State private var archetype: Archetype?
    @State private var reasoning = ""
    @State private var phasePercents: [Int] = []
    @State private var totalHours: Int = 40
    @State private var generatedPhases: StrategyChatEngine.PhaseResult?
    @State private var generatedMilestones: StrategyChatEngine.MilestoneResult?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    private let engine = StrategyChatEngine()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Step content
                        stepContent
                            .id("content")
                    }
                    .padding()
                }
                .onChange(of: step) { _, _ in
                    withAnimation {
                        proxy.scrollTo("content", anchor: .top)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plan Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .idle:
            goalInputSection

        case .classifying:
            loadingSection("Analyzing your goal...")

        case .phaseReview:
            if projectMode == .phase {
                phaseAllocationSection
            } else {
                milestoneReviewSection
            }

        case .generatingSessions:
            loadingSection("Generating plan...")

        case .sessionReview:
            planReviewSection

        case .done:
            EmptyView()
        }
    }

    // MARK: - Goal Input Section

    private var goalInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Intro message
            chatBubble(
                "What do you want to accomplish? Describe your goal and I'll help you plan it.",
                isAssistant: true
            )

            // Goal input
            VStack(alignment: .leading, spacing: 8) {
                TextField("e.g., Write a research paper on ML optimization", text: $goal, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .lineLimit(3...6)

                Button {
                    classifyGoal()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Plan This")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(prefs.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            }
        }
    }

    // MARK: - Phase Allocation Section (Phase Mode)

    private var phaseAllocationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Classification result
            chatBubble(
                "I recommend **Phase Mode** for this \(archetype?.displayName.lowercased() ?? "project"): \(reasoning)",
                isAssistant: true
            )

            // Project title input
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Title")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Project title", text: $projectTitle)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Time budget
            VStack(alignment: .leading, spacing: 8) {
                Text("Total Time Budget")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Stepper("\(totalHours) hours", value: $totalHours, in: 5...200, step: 5)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Phase allocation sliders
            if let arch = archetype {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Phase Time Allocation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(Array(arch.phaseStructure.enumerated()), id: \.offset) { index, template in
                        PhaseAllocationCard(
                            phaseName: template.name,
                            phaseType: template.type,
                            mentalRule: template.rule,
                            index: index,
                            percent: binding(for: index),
                            totalMinutes: totalHours * 60,
                            onAdjust: { delta in
                                adjustPercent(for: index, by: delta)
                            }
                        )
                    }
                }
            }

            // Generate button
            Button {
                generatePlan()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Phases")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(prefs.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(projectTitle.isEmpty || isProcessing)
        }
    }

    // MARK: - Milestone Review Section (Milestone Mode)

    private var milestoneReviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Classification result
            chatBubble(
                "I recommend **Milestone Mode** for this task: \(reasoning)",
                isAssistant: true
            )

            // Project title input
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Title")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Project title", text: $projectTitle)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Generate button
            Button {
                generatePlan()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Milestones")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(prefs.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(projectTitle.isEmpty || isProcessing)
        }
    }

    // MARK: - Plan Review Section

    private var planReviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Review intro
            chatBubble(
                projectMode == .phase
                    ? "Here are the phases I suggest. Review them and create your project when ready."
                    : "Here are the milestones I suggest. Review them and create your project when ready.",
                isAssistant: true
            )

            // Project summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(projectTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(projectMode == .phase ? "PHASE" : "MILESTONE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(prefs.accentColor.opacity(0.15))
                        .clipShape(Capsule())

                    if let arch = archetype {
                        Text(arch.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                if projectMode == .phase {
                    Text("\(totalHours) hours total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Phases or milestones list
            if projectMode == .phase, let phases = generatedPhases {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(phases.phases.enumerated()), id: \.offset) { index, phase in
                        phasePreviewRow(phase, index: index)
                    }
                }
            } else if let milestones = generatedMilestones {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(milestones.milestones.enumerated()), id: \.offset) { index, milestone in
                        milestonePreviewRow(milestone, index: index)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    step = .phaseReview
                } label: {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    createProject()
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Create Project")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(prefs.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Preview Rows

    private func phasePreviewRow(_ phase: StrategyChatEngine.PhasePlan, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(index + 1). \(phase.name)")
                    .font(.headline)
                Spacer()
                Text("\(phase.estimatedMinutes / 60)h")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !phase.mentalRule.isEmpty {
                Text("\"\(phase.mentalRule)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func milestonePreviewRow(_ milestone: StrategyChatEngine.MilestonePlan, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !milestone.description.isEmpty {
                    Text(milestone.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Loading Section

    private func loadingSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ message: String, isAssistant: Bool) -> some View {
        HStack {
            if !isAssistant { Spacer() }

            Text(try! AttributedString(markdown: message))
                .padding()
                .background(isAssistant ? Color(.secondarySystemGroupedBackground) : prefs.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if isAssistant { Spacer() }
        }
    }

    // MARK: - Actions

    private func classifyGoal() {
        isProcessing = true
        step = .classifying

        Task {
            do {
                let result = try await engine.classifyGoal(goal)
                await MainActor.run {
                    projectTitle = result.suggestedTitle
                    reasoning = result.reasoning

                    if result.mode == "milestone" {
                        projectMode = .milestone
                        archetype = nil
                    } else {
                        projectMode = .phase
                        if let arch = result.archetype, let a = Archetype(rawValue: arch.lowercased()) {
                            archetype = a
                            phasePercents = a.phaseStructure.map { $0.defaultPercent }
                        }
                    }

                    step = .phaseReview
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    step = .idle
                    isProcessing = false
                }
            }
        }
    }

    private func generatePlan() {
        isProcessing = true
        step = .generatingSessions

        Task {
            do {
                if projectMode == .phase, let arch = archetype {
                    var allocation = StrategyChatEngine.PhaseAllocation(
                        archetype: arch,
                        totalMinutes: totalHours * 60
                    )
                    allocation.phasePercents = phasePercents

                    let result = try await engine.generatePhases(
                        title: projectTitle,
                        goal: goal,
                        allocation: allocation
                    )
                    await MainActor.run {
                        generatedPhases = result
                        step = .sessionReview
                        isProcessing = false
                    }
                } else {
                    let result = try await engine.generateMilestones(
                        title: projectTitle,
                        goal: goal
                    )
                    await MainActor.run {
                        generatedMilestones = result
                        step = .sessionReview
                        isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    step = .phaseReview
                    isProcessing = false
                }
            }
        }
    }

    private func createProject() {
        Task {
            if projectMode == .phase, let arch = archetype, let phases = generatedPhases {
                var allocation = StrategyChatEngine.PhaseAllocation(
                    archetype: arch,
                    totalMinutes: totalHours * 60
                )
                allocation.phasePercents = phasePercents

                let (project, projectPhases) = await engine.createPhaseProject(
                    title: projectTitle,
                    archetype: arch,
                    allocation: allocation,
                    phaseResult: phases
                )

                await MainActor.run {
                    modelContext.insert(project)
                    for phase in projectPhases {
                        modelContext.insert(phase)
                    }
                    dismiss()
                }
            } else if let milestones = generatedMilestones {
                let (project, projectMilestones) = await engine.createMilestoneProject(
                    title: projectTitle,
                    milestoneResult: milestones
                )

                await MainActor.run {
                    modelContext.insert(project)
                    for milestone in projectMilestones {
                        modelContext.insert(milestone)
                    }
                    dismiss()
                }
            }
        }
    }

    // MARK: - Helpers

    private func binding(for index: Int) -> Binding<Int> {
        Binding(
            get: { index < phasePercents.count ? phasePercents[index] : 0 },
            set: { phasePercents[index] = $0 }
        )
    }

    /// Adjust a phase's percentage while keeping the total at 100%
    private func adjustPercent(for index: Int, by delta: Int) {
        guard index < phasePercents.count else { return }

        let oldValue = phasePercents[index]
        let newValue = max(5, min(80, oldValue + delta))
        let actualDelta = newValue - oldValue

        if actualDelta == 0 { return }

        // Apply the change
        phasePercents[index] = newValue

        // Distribute the opposite delta to other phases
        distributePercentDelta(-actualDelta, excludingIndex: index)
    }

    /// Distribute a delta across phases (excluding one) to keep total at 100%
    private func distributePercentDelta(_ delta: Int, excludingIndex: Int) {
        guard phasePercents.count > 1, delta != 0 else { return }

        let otherIndices = phasePercents.indices.filter { $0 != excludingIndex }
        let perPhase = delta / otherIndices.count
        var remainder = delta % otherIndices.count

        for i in otherIndices {
            let adjustment = perPhase + (remainder > 0 ? 1 : (remainder < 0 ? -1 : 0))
            phasePercents[i] = max(5, min(80, phasePercents[i] + adjustment))
            if remainder > 0 { remainder -= 1 }
            if remainder < 0 { remainder += 1 }
        }
    }
}

#Preview {
    StrategicPlanningChatView()
        .modelContainer(for: [Project.self, ProjectPhase.self, Milestone.self], inMemory: true)
}
