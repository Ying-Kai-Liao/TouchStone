import Foundation

actor StrategyEngine {
    private let openAI = OpenAIClient()

    // MARK: - Response Types

    struct StrategyPlan: Codable {
        let archetype: String
        let phases: [PhasePlan]
        let totalEstimatedMinutes: Int
    }

    struct PhasePlan: Codable {
        let name: String
        let type: String
        let mentalRule: String
        let sessions: [SessionPlan]
    }

    struct SessionPlan: Codable {
        let title: String
        let goal: String
        let estimatedMinutes: Int
    }

    // MARK: - Generate Plan

    func generatePlan(for goal: String) async throws -> StrategyPlan {
        let systemPrompt = """
        You are a strategic planning assistant that helps break down large goals into manageable phases and sessions.

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

        PHASE PATTERNS by archetype:
        - lab: Research (divergent) → Synthesis (convergent) → Output (output)
        - hunt: Audit (input) → Gather (execution) → Execute (output)
        - spiral: Input (input) → Practice (output) → Reflection (reflection)
        - build: Spec (convergent) → Dependencies (execution) → Assembly (output) → Testing (reflection)

        Create 2-4 PHASES with 2-5 SESSIONS each.
        Sessions should be 60-90 minute focused work blocks.
        Each phase needs a MENTAL RULE - a cognitive constraint like:
        - "Explore widely, no conclusions yet"
        - "Write fast, don't edit"
        - "Focus on quantity over quality"
        - "Only organize, don't create"

        Return ONLY valid JSON matching this exact structure:
        {
            "archetype": "lab|hunt|spiral|build",
            "phases": [
                {
                    "name": "Phase Name",
                    "type": "divergent|convergent|execution|input|output|reflection",
                    "mentalRule": "The cognitive constraint for this phase",
                    "sessions": [
                        {
                            "title": "Session title",
                            "goal": "Specific goal for this session",
                            "estimatedMinutes": 60
                        }
                    ]
                }
            ],
            "totalEstimatedMinutes": 360
        }
        """

        let userMessage = "Break down this goal into phases and sessions: \(goal)"

        return try await openAI.chatJSON(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.7,
            responseType: StrategyPlan.self
        )
    }

    // MARK: - Convert to Models

    func createProjectFromPlan(
        title: String,
        plan: StrategyPlan
    ) -> (Project, [ProjectPhase]) {
        let archetype = Archetype(rawValue: plan.archetype.lowercased())

        let project = Project(
            title: title,
            archetype: archetype
        )

        var projectPhases: [ProjectPhase] = []

        for (index, phasePlan) in plan.phases.enumerated() {
            let phaseType = PhaseType(rawValue: phasePlan.type.lowercased()) ?? .execution

            let phase = ProjectPhase(
                title: phasePlan.name,
                phaseType: phaseType,
                mentalRule: phasePlan.mentalRule,
                sequenceOrder: index
            )
            phase.project = project

            for (sessionIndex, sessionPlan) in phasePlan.sessions.enumerated() {
                let session = PlannedSession(
                    title: sessionPlan.title,
                    goal: sessionPlan.goal,
                    estimatedMinutes: sessionPlan.estimatedMinutes,
                    sequenceOrder: sessionIndex
                )
                session.phase = phase
                phase.sessions.append(session)
            }

            projectPhases.append(phase)
        }

        project.phases = projectPhases
        return (project, projectPhases)
    }
}

// MARK: - Preview/Mock Data

extension StrategyEngine {
    static func mockPlan() -> StrategyPlan {
        StrategyPlan(
            archetype: "lab",
            phases: [
                PhasePlan(
                    name: "Research",
                    type: "divergent",
                    mentalRule: "Explore widely, no conclusions yet",
                    sessions: [
                        SessionPlan(title: "Literature review", goal: "Find and read 5 key papers", estimatedMinutes: 90),
                        SessionPlan(title: "Concept mapping", goal: "Map relationships between ideas", estimatedMinutes: 60)
                    ]
                ),
                PhasePlan(
                    name: "Draft",
                    type: "convergent",
                    mentalRule: "Write fast, don't edit",
                    sessions: [
                        SessionPlan(title: "Outline structure", goal: "Create 5-section skeleton", estimatedMinutes: 60),
                        SessionPlan(title: "First draft sprint", goal: "Write 2000 words minimum", estimatedMinutes: 90)
                    ]
                ),
                PhasePlan(
                    name: "Polish",
                    type: "output",
                    mentalRule: "Refine and perfect",
                    sessions: [
                        SessionPlan(title: "Review and rewrite", goal: "Edit for clarity and flow", estimatedMinutes: 90),
                        SessionPlan(title: "Final formatting", goal: "Format citations, figures", estimatedMinutes: 60)
                    ]
                )
            ],
            totalEstimatedMinutes: 450
        )
    }
}
