import Foundation

actor StrategyEngine {
    private let openAI = OpenAIClient()

    // MARK: - Response Types

    /// Classification result for determining project mode
    struct ModeClassification: Codable {
        let mode: String          // "phase" or "milestone"
        let archetype: String?    // Only for phase mode
        let reasoning: String
    }

    /// Phase-mode plan structure
    struct PhasePlan: Codable {
        let archetype: String
        let phases: [PhaseDetail]
        let totalEstimatedMinutes: Int
    }

    struct PhaseDetail: Codable {
        let name: String
        let type: String
        let mentalRule: String
        let estimatedMinutes: Int
    }

    /// Milestone-mode plan structure
    struct MilestonePlan: Codable {
        let milestones: [MilestoneDetail]
    }

    struct MilestoneDetail: Codable {
        let title: String
        let description: String
    }

    // MARK: - Generate Phase-Mode Plan

    func generatePhasePlan(for goal: String) async throws -> PhasePlan {
        let systemPrompt = """
        You are a strategic planning assistant that helps break down large goals into cognitive phases.

        ARCHETYPES - Classify the goal into ONE of these:
        - lab: Creative work, research, writing, design, exploration
        - hunt: Administrative tasks, paperwork, applications, bureaucratic work
        - spiral: Learning new skills, practice, study, skill acquisition
        - build: Engineering, coding, construction, building things

        PHASE TYPES - Each phase should have one of these types:
        - divergent: Explore widely, brainstorm, gather options
        - convergent: Focus, synthesize, narrow down, decide
        - execution: Do the actual work
        - input: Learn, absorb, take in information
        - output: Produce, create, deliver
        - reflection: Review, iterate, improve

        Create 2-4 PHASES with TIME BUDGETS (not individual sessions).
        Each phase needs a MENTAL RULE - a cognitive constraint like:
        - "Explore widely, no conclusions yet"
        - "Write fast, don't edit"
        - "Focus on quantity over quality"

        Return ONLY valid JSON matching this exact structure:
        {
            "archetype": "lab|hunt|spiral|build",
            "phases": [
                {
                    "name": "Phase Name",
                    "type": "divergent|convergent|execution|input|output|reflection",
                    "mentalRule": "The cognitive constraint for this phase",
                    "estimatedMinutes": 120
                }
            ],
            "totalEstimatedMinutes": 360
        }
        """

        let userMessage = "Break down this goal into phases: \(goal)"

        return try await openAI.chatJSON(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.7,
            responseType: PhasePlan.self
        )
    }

    // MARK: - Generate Milestone-Mode Plan

    func generateMilestonePlan(for goal: String) async throws -> MilestonePlan {
        let systemPrompt = """
        You are a strategic planning assistant that helps break down task-oriented goals into milestones.

        Create 3-8 MILESTONES that represent clear deliverables.
        Each milestone should be something the user can CHECK OFF when done.
        Order milestones in logical sequence.

        Return ONLY valid JSON matching this exact structure:
        {
            "milestones": [
                {
                    "title": "Clear deliverable name",
                    "description": "What this milestone involves"
                }
            ]
        }
        """

        let userMessage = "Break down this goal into milestones: \(goal)"

        return try await openAI.chatJSON(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.7,
            responseType: MilestonePlan.self
        )
    }

    // MARK: - Convert to Phase-Mode Project

    func createPhaseProjectFromPlan(
        title: String,
        plan: PhasePlan
    ) -> (Project, [ProjectPhase]) {
        let archetype = Archetype(rawValue: plan.archetype.lowercased())

        let project = Project(
            title: title,
            mode: .phase,
            archetype: archetype,
            totalPlannedMinutes: plan.totalEstimatedMinutes
        )

        var projectPhases: [ProjectPhase] = []

        for (index, phaseDetail) in plan.phases.enumerated() {
            let phaseType = PhaseType(rawValue: phaseDetail.type.lowercased()) ?? .execution

            let phase = ProjectPhase(
                title: phaseDetail.name,
                phaseType: phaseType,
                mentalRule: phaseDetail.mentalRule,
                sequenceOrder: index,
                estimatedMinutes: phaseDetail.estimatedMinutes
            )
            phase.project = project
            projectPhases.append(phase)
        }

        project.phases = projectPhases
        return (project, projectPhases)
    }

    // MARK: - Convert to Milestone-Mode Project

    func createMilestoneProjectFromPlan(
        title: String,
        plan: MilestonePlan
    ) -> (Project, [Milestone]) {
        let project = Project(
            title: title,
            mode: .milestone
        )

        var milestones: [Milestone] = []

        for (index, milestoneDetail) in plan.milestones.enumerated() {
            let milestone = Milestone(
                title: milestoneDetail.title,
                descriptionText: milestoneDetail.description,
                sequenceOrder: index
            )
            milestone.project = project
            milestones.append(milestone)
        }

        project.milestones = milestones
        return (project, milestones)
    }
}

// MARK: - Preview/Mock Data

extension StrategyEngine {
    static func mockPhasePlan() -> PhasePlan {
        PhasePlan(
            archetype: "lab",
            phases: [
                PhaseDetail(
                    name: "Research",
                    type: "divergent",
                    mentalRule: "Explore widely, no conclusions yet",
                    estimatedMinutes: 180
                ),
                PhaseDetail(
                    name: "Draft",
                    type: "execution",
                    mentalRule: "Write fast, don't edit",
                    estimatedMinutes: 300
                ),
                PhaseDetail(
                    name: "Polish",
                    type: "convergent",
                    mentalRule: "Refine and perfect",
                    estimatedMinutes: 120
                )
            ],
            totalEstimatedMinutes: 600
        )
    }

    static func mockMilestonePlan() -> MilestonePlan {
        MilestonePlan(
            milestones: [
                MilestoneDetail(title: "Gather W2s and 1099s", description: "Collect all income documents"),
                MilestoneDetail(title: "Collect deduction receipts", description: "Organize all deductible expenses"),
                MilestoneDetail(title: "Complete federal return", description: "Fill out Form 1040"),
                MilestoneDetail(title: "Submit e-file", description: "File electronically")
            ]
        )
    }
}
