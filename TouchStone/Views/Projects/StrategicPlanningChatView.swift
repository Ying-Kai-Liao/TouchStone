import SwiftUI
import SwiftData

/// Chat-based strategic planning flow with generative UI
struct StrategicPlanningChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var step: StrategyChatEngine.ChatStep = .idle
    @State private var goal = ""
    @State private var projectTitle = ""
    @State private var archetype: Archetype?
    @State private var reasoning = ""
    @State private var phasePercents: [Int] = []
    @State private var totalHours: Int = 40
    @State private var generatedSessions: StrategyChatEngine.SessionsResult?
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
            phaseAllocationSection

        case .generatingSessions:
            loadingSection("Generating session goals...")

        case .sessionReview:
            sessionReviewSection

        case .done:
            EmptyView()
        }
    }

    // MARK: - Goal Input Section

    private var goalInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Intro message
            chatBubble(
                "What do you want to accomplish? Describe your project goal and I'll help you plan it strategically.",
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
                        Text("Generate Plan")
                        Image(systemName: "sparkles")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(goal.isEmpty ? Color.gray : Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(goal.isEmpty || isProcessing)
            }
        }
    }

    // MARK: - Phase Allocation Section

    private var phaseAllocationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Classification result bubble
            if let arch = archetype {
                chatBubble(
                    "I identified this as a **\(arch.displayName)** project.\n\n\(reasoning)",
                    isAssistant: true
                )
            }

            // Archetype badge
            if let arch = archetype {
                HStack {
                    Image(systemName: arch.icon)
                        .foregroundStyle(.purple)
                    Text(arch.displayName)
                        .fontWeight(.bold)
                    Text("Project Structure")
                        .foregroundStyle(.secondary)
                }
                .font(.headline)
            }

            // Title field
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

            // Total time control
            TotalTimeControl(totalHours: $totalHours)

            // Phase cards
            if let arch = archetype {
                ForEach(Array(arch.phaseStructure.enumerated()), id: \.offset) { index, template in
                    PhaseAllocationCard(
                        phaseName: template.name,
                        phaseType: template.type,
                        mentalRule: template.rule,
                        index: index,
                        percent: binding(for: index),
                        totalMinutes: totalHours * 60,
                        onAdjust: { delta in adjustPhasePercent(index: index, delta: delta) }
                    )
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    step = .idle
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Start Over")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    generateSessions()
                } label: {
                    HStack {
                        Text("Looks Good")
                        Image(systemName: "arrow.right")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(projectTitle.isEmpty || isProcessing)
            }
        }
    }

    // MARK: - Session Review Section

    private var sessionReviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sessions intro
            chatBubble(
                "Here are the session goals I suggest based on your time allocation. Review them and create your project when ready.",
                isAssistant: true
            )

            // Project summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(projectTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let arch = archetype {
                        Text(arch.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text("\(totalHours) hours total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Sessions list
            if let sessions = generatedSessions, let arch = archetype {
                SessionGoalsList(
                    phases: sessions.phases,
                    phaseStructure: arch.phaseStructure
                )
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    step = .phaseReview
                } label: {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Adjust Time")
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
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
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
                .background(isAssistant ? Color(.secondarySystemGroupedBackground) : Color.purple.opacity(0.15))
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
                    if let arch = Archetype(rawValue: result.archetype.lowercased()) {
                        archetype = arch
                        reasoning = result.reasoning
                        projectTitle = result.suggestedTitle
                        phasePercents = arch.phaseStructure.map { $0.defaultPercent }
                        step = .phaseReview
                    } else {
                        errorMessage = "Could not determine project type. Please try again."
                        step = .idle
                    }
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

    private func generateSessions() {
        guard let arch = archetype else { return }

        isProcessing = true
        step = .generatingSessions

        var allocation = StrategyChatEngine.PhaseAllocation(
            archetype: arch,
            totalMinutes: totalHours * 60
        )
        allocation.phasePercents = phasePercents

        Task {
            do {
                let result = try await engine.generateSessions(
                    title: projectTitle,
                    goal: goal,
                    allocation: allocation
                )
                await MainActor.run {
                    generatedSessions = result
                    step = .sessionReview
                    isProcessing = false
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
        guard let arch = archetype,
              let sessions = generatedSessions else { return }

        var allocation = StrategyChatEngine.PhaseAllocation(
            archetype: arch,
            totalMinutes: totalHours * 60
        )
        allocation.phasePercents = phasePercents

        Task {
            let (project, phases) = await engine.createProject(
                title: projectTitle,
                archetype: arch,
                allocation: allocation,
                sessionsResult: sessions
            )

            await MainActor.run {
                modelContext.insert(project)
                for phase in phases {
                    modelContext.insert(phase)
                    for session in phase.sessions {
                        modelContext.insert(session)
                    }
                }
                dismiss()
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

    private func adjustPhasePercent(index: Int, delta: Int) {
        guard index >= 0 && index < phasePercents.count else { return }

        let oldPercent = phasePercents[index]
        let newPercent = max(5, min(80, oldPercent + delta))

        if newPercent != oldPercent {
            phasePercents[index] = newPercent

            // Redistribute to other phases
            let actualDelta = newPercent - oldPercent
            redistributePercents(excludingIndex: index, delta: -actualDelta)
        }
    }

    private func redistributePercents(excludingIndex: Int, delta: Int) {
        let otherIndices = phasePercents.indices.filter { $0 != excludingIndex }
        guard !otherIndices.isEmpty else { return }

        let totalOther = otherIndices.reduce(0) { $0 + phasePercents[$1] }
        guard totalOther > 0 else { return }

        var remaining = delta
        for (i, idx) in otherIndices.enumerated() {
            let share: Int
            if i == otherIndices.count - 1 {
                share = remaining
            } else {
                share = (delta * phasePercents[idx]) / totalOther
            }
            phasePercents[idx] = max(5, min(80, phasePercents[idx] + share))
            remaining -= share
        }

        // Normalize to 100%
        let total = phasePercents.reduce(0, +)
        if total != 100 {
            let diff = 100 - total
            if let maxIdx = phasePercents.indices.max(by: { phasePercents[$0] < phasePercents[$1] }) {
                phasePercents[maxIdx] += diff
            }
        }
    }
}

#Preview {
    StrategicPlanningChatView()
        .modelContainer(for: [Project.self, ProjectPhase.self, PlannedSession.self], inMemory: true)
}
