import Foundation

/// Chat-based strategy planning engine with two-step flow:
/// 1. Classify goal into archetype
/// 2. Generate sessions based on user's time allocation
actor StrategyChatEngine {
    private let openAI = OpenAIClient()

    // MARK: - Chat Step States

    enum ChatStep: Equatable {
        case idle
        case classifying
        case phaseReview
        case generatingSessions
        case sessionReview
        case done
    }

    // MARK: - Response Types

    struct ClassificationResult: Codable {
        let mode: String          // "phase" or "milestone"
        let archetype: String?    // Only for phase mode
        let reasoning: String
        let suggestedTitle: String
    }

    struct PhaseResult: Codable {
        let phases: [PhasePlan]
    }

    struct PhasePlan: Codable {
        let name: String
        let phaseType: String
        let mentalRule: String
        let estimatedMinutes: Int
    }

    struct MilestoneResult: Codable {
        let milestones: [MilestonePlan]
    }

    struct MilestonePlan: Codable {
        let title: String
        let description: String
    }

    // MARK: - Phase Allocation

    struct PhaseAllocation {
        var archetype: Archetype
        var phasePercents: [Int]
        var totalMinutes: Int

        init(archetype: Archetype, totalMinutes: Int = 2400) { // 40 hours default
            self.archetype = archetype
            self.totalMinutes = totalMinutes
            self.phasePercents = archetype.phaseStructure.map { $0.defaultPercent }
        }

        mutating func setPhasePercent(index: Int, percent: Int) {
            guard index >= 0 && index < phasePercents.count else { return }

            let oldPercent = phasePercents[index]
            let delta = percent - oldPercent

            // Clamp to 5-80%
            let newPercent = max(5, min(80, percent))
            phasePercents[index] = newPercent

            // Redistribute delta to other phases proportionally
            let actualDelta = newPercent - oldPercent
            if actualDelta != 0 {
                redistributePercents(excludingIndex: index, delta: -actualDelta)
            }
        }

        private mutating func redistributePercents(excludingIndex: Int, delta: Int) {
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

            // Ensure total is 100%
            normalizePercents()
        }

        private mutating func normalizePercents() {
            let total = phasePercents.reduce(0, +)
            if total != 100 {
                let diff = 100 - total
                if let maxIdx = phasePercents.indices.max(by: { phasePercents[$0] < phasePercents[$1] }) {
                    phasePercents[maxIdx] += diff
                }
            }
        }

        func minutesForPhase(_ index: Int) -> Int {
            guard index >= 0 && index < phasePercents.count else { return 0 }
            return (totalMinutes * phasePercents[index]) / 100
        }

        func sessionsForPhase(_ index: Int, sessionDuration: Int = 75) -> Int {
            let minutes = minutesForPhase(index)
            return max(1, minutes / sessionDuration)
        }
    }

    // MARK: - Step 1: Classify Goal and Determine Mode

    func classifyGoal(_ goal: String) async throws -> ClassificationResult {
        let systemPrompt = """
        You are a strategic planning assistant. Analyze the user's goal and determine:
        1. The best MODE for this project
        2. The ARCHETYPE (if phase mode)

        MODES:
        - phase: For creative/research work where the PROCESS matters. Work is tracked by time invested per phase.
          Best for: writing, research, design, learning, skill building
        - milestone: For task-oriented work with clear DELIVERABLES. Work is tracked by checking off items.
          Best for: tax filing, moving, errands, applications, administrative tasks

        ARCHETYPES (only for phase mode):
        - lab: Creative work, research, writing, design
        - hunt: Administrative tasks, paperwork, applications
        - spiral: Learning new skills, practice, study
        - build: Engineering, coding, construction

        Return ONLY valid JSON matching this structure:
        {
            "mode": "phase|milestone",
            "archetype": "lab|hunt|spiral|build or null",
            "reasoning": "One sentence explaining your choice",
            "suggestedTitle": "Action-oriented project title (3-5 words)"
        }
        """

        let userMessage = "Classify this goal: \(goal)"

        return try await openAI.chatJSON(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.5,
            responseType: ClassificationResult.self
        )
    }

    // MARK: - Step 2a: Generate Phases (Phase Mode)

    func generatePhases(
        title: String,
        goal: String,
        allocation: PhaseAllocation
    ) async throws -> PhaseResult {
        let phaseDescriptions = allocation.archetype.phaseStructure.enumerated().map { index, template in
            let minutes = allocation.minutesForPhase(index)
            return """
            Phase \(index + 1): \(template.name) (\(template.type.displayName))
            - Time Budget: \(minutes) minutes (~\(minutes / 60) hours)
            - Mental Rule: "\(template.rule)"
            """
        }.joined(separator: "\n\n")

        let systemPrompt = """
        You are a strategic planning assistant creating cognitive phases for a project.

        PROJECT: \(title)
        GOAL: \(goal)
        ARCHETYPE: \(allocation.archetype.displayName)

        PHASE STRUCTURE:
        \(phaseDescriptions)

        Create phases with TIME BUDGETS (not individual sessions).
        Each phase has a mental rule that guides the user's mindset.

        Return ONLY valid JSON matching this structure:
        {
            "phases": [
                {
                    "name": "Phase Name",
                    "phaseType": "divergent|convergent|execution|input|output|reflection",
                    "mentalRule": "The cognitive constraint for this phase",
                    "estimatedMinutes": 120
                }
            ]
        }
        """

        let userMessage = "Generate phases for this project."

        return try await openAI.chatJSON(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.7,
            responseType: PhaseResult.self
        )
    }

    // MARK: - Step 2b: Generate Milestones (Milestone Mode)

    func generateMilestones(
        title: String,
        goal: String
    ) async throws -> MilestoneResult {
        let systemPrompt = """
        You are a strategic planning assistant creating checkable milestones for a task-oriented project.

        PROJECT: \(title)
        GOAL: \(goal)

        Create 3-8 milestones that represent clear deliverables.
        Each milestone should be something the user can CHECK OFF when done.
        Order milestones in logical sequence.

        Return ONLY valid JSON matching this structure:
        {
            "milestones": [
                {
                    "title": "Clear deliverable name",
                    "description": "What this milestone involves"
                }
            ]
        }
        """

        let userMessage = "Generate milestones for this project."

        return try await openAI.chatJSON(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.7,
            responseType: MilestoneResult.self
        )
    }

    // MARK: - Create Phase-Mode Project

    func createPhaseProject(
        title: String,
        archetype: Archetype,
        allocation: PhaseAllocation,
        phaseResult: PhaseResult
    ) -> (Project, [ProjectPhase]) {
        let project = Project(
            title: title,
            mode: .phase,
            archetype: archetype,
            totalPlannedMinutes: allocation.totalMinutes
        )

        var projectPhases: [ProjectPhase] = []

        for (index, phasePlan) in phaseResult.phases.enumerated() {
            let phaseType = PhaseType(rawValue: phasePlan.phaseType.lowercased()) ?? .execution

            let phase = ProjectPhase(
                title: phasePlan.name,
                phaseType: phaseType,
                mentalRule: phasePlan.mentalRule,
                sequenceOrder: index,
                estimatedMinutes: phasePlan.estimatedMinutes
            )
            phase.project = project
            projectPhases.append(phase)
        }

        project.phases = projectPhases
        return (project, projectPhases)
    }

    // MARK: - Create Milestone-Mode Project

    func createMilestoneProject(
        title: String,
        milestoneResult: MilestoneResult
    ) -> (Project, [Milestone]) {
        let project = Project(
            title: title,
            mode: .milestone
        )

        var milestones: [Milestone] = []

        for (index, milestonePlan) in milestoneResult.milestones.enumerated() {
            let milestone = Milestone(
                title: milestonePlan.title,
                descriptionText: milestonePlan.description,
                sequenceOrder: index
            )
            milestone.project = project
            milestones.append(milestone)
        }

        project.milestones = milestones
        return (project, milestones)
    }
}

// MARK: - Mock Data for Previews

extension StrategyChatEngine {
    static func mockClassificationPhase() -> ClassificationResult {
        ClassificationResult(
            mode: "phase",
            archetype: "lab",
            reasoning: "This is a research and writing project requiring exploration followed by synthesis.",
            suggestedTitle: "ML Optimization Research"
        )
    }

    static func mockClassificationMilestone() -> ClassificationResult {
        ClassificationResult(
            mode: "milestone",
            archetype: nil,
            reasoning: "This is a task-oriented project with clear deliverables to check off.",
            suggestedTitle: "Tax Filing 2025"
        )
    }

    static func mockPhases() -> PhaseResult {
        PhaseResult(
            phases: [
                PhasePlan(
                    name: "Exploration",
                    phaseType: "divergent",
                    mentalRule: "Explore widely, no conclusions yet. Let ideas marinate.",
                    estimatedMinutes: 180
                ),
                PhasePlan(
                    name: "Bricklaying",
                    phaseType: "execution",
                    mentalRule: "Hermit mode: no new inputs, no editing worry, just produce.",
                    estimatedMinutes: 360
                ),
                PhasePlan(
                    name: "Refining",
                    phaseType: "convergent",
                    mentalRule: "No new research, only polish and perfect.",
                    estimatedMinutes: 180
                )
            ]
        )
    }

    static func mockMilestones() -> MilestoneResult {
        MilestoneResult(
            milestones: [
                MilestonePlan(title: "Gather W2s and 1099s", description: "Collect all income documents from employers and banks"),
                MilestonePlan(title: "Collect deduction receipts", description: "Organize charitable donations, medical expenses, business costs"),
                MilestonePlan(title: "Complete federal return", description: "Fill out Form 1040 with all schedules"),
                MilestonePlan(title: "Complete state return", description: "Fill out state tax form"),
                MilestonePlan(title: "Submit e-file", description: "E-file or mail completed returns")
            ]
        )
    }
}
