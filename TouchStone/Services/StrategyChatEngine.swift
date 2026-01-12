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
        let archetype: String
        let reasoning: String
        let suggestedTitle: String
    }

    struct SessionsResult: Codable {
        let phases: [PhasePlan]
    }

    struct PhasePlan: Codable {
        let name: String
        let sessions: [SessionPlan]
    }

    struct SessionPlan: Codable {
        let title: String
        let goal: String
        let estimatedMinutes: Int
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

    // MARK: - Step 1: Classify Goal

    func classifyGoal(_ goal: String) async throws -> ClassificationResult {
        let systemPrompt = """
        You are a strategic planning assistant. Analyze the user's goal and classify it into ONE archetype.

        ARCHETYPES:
        - lab: Creative work, research, writing, design. User needs to explore then synthesize.
               Failure mode: Getting stuck in research forever.
        - hunt: Administrative tasks, paperwork, applications.
               Failure mode: Missing one document and getting blocked.
        - spiral: Learning new skills, practice, study.
               Failure mode: Passive consumption without doing.
        - build: Engineering, coding, construction, building things.
               Failure mode: Starting before materials ready.

        Return ONLY valid JSON matching this structure:
        {
            "archetype": "lab|hunt|spiral|build",
            "reasoning": "One sentence explaining why this archetype fits",
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

    // MARK: - Step 2: Generate Sessions

    func generateSessions(
        title: String,
        goal: String,
        allocation: PhaseAllocation
    ) async throws -> SessionsResult {
        let phaseDescriptions = allocation.archetype.phaseStructure.enumerated().map { index, template in
            let minutes = allocation.minutesForPhase(index)
            let sessionCount = allocation.sessionsForPhase(index)
            return """
            Phase \(index + 1): \(template.name) (\(template.type.displayName))
            - Time: \(minutes) minutes (~\(sessionCount) sessions of 60-90 min)
            - Mental Rule: "\(template.rule)"
            """
        }.joined(separator: "\n\n")

        let systemPrompt = """
        You are a strategic planning assistant creating focused work sessions for a project.

        PROJECT: \(title)
        GOAL: \(goal)
        ARCHETYPE: \(allocation.archetype.displayName)

        PHASE STRUCTURE:
        \(phaseDescriptions)

        RULES:
        1. Create sessions for EACH phase with the specified session count
        2. Each session should be 60-90 minutes
        3. Session goals MUST align with the phase's mental rule
        4. Be specific and actionable (e.g., "Write 1000 words" not "Write some")
        5. Earlier sessions in a phase should build toward later ones

        Return ONLY valid JSON matching this structure:
        {
            "phases": [
                {
                    "name": "Phase Name",
                    "sessions": [
                        {"title": "Session title", "goal": "Specific measurable goal", "estimatedMinutes": 60}
                    ]
                }
            ]
        }
        """

        let userMessage = "Generate session goals for this project."

        return try await openAI.chatJSON(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.7,
            responseType: SessionsResult.self
        )
    }

    // MARK: - Create Project from Results

    func createProject(
        title: String,
        archetype: Archetype,
        allocation: PhaseAllocation,
        sessionsResult: SessionsResult
    ) -> (Project, [ProjectPhase]) {
        let project = Project(
            title: title,
            archetype: archetype
        )

        var projectPhases: [ProjectPhase] = []
        let phaseStructure = archetype.phaseStructure

        for (index, phasePlan) in sessionsResult.phases.enumerated() {
            guard index < phaseStructure.count else { continue }

            let template = phaseStructure[index]

            let phase = ProjectPhase(
                title: phasePlan.name,
                phaseType: template.type,
                mentalRule: template.rule,
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

// MARK: - Mock Data for Previews

extension StrategyChatEngine {
    static func mockClassification() -> ClassificationResult {
        ClassificationResult(
            archetype: "lab",
            reasoning: "This is a research and writing project requiring exploration followed by synthesis.",
            suggestedTitle: "ML Optimization Research"
        )
    }

    static func mockSessions() -> SessionsResult {
        SessionsResult(
            phases: [
                PhasePlan(
                    name: "Exploration",
                    sessions: [
                        SessionPlan(title: "Literature Safari", goal: "Find and bookmark 15 related papers on ML optimization", estimatedMinutes: 90),
                        SessionPlan(title: "Concept Mapping", goal: "Create a mind map connecting key optimization techniques", estimatedMinutes: 75),
                        SessionPlan(title: "Dataset Discovery", goal: "Identify 3 potential benchmark datasets", estimatedMinutes: 60)
                    ]
                ),
                PhasePlan(
                    name: "Bricklaying",
                    sessions: [
                        SessionPlan(title: "Outline Sprint", goal: "Create full document skeleton with section headers", estimatedMinutes: 60),
                        SessionPlan(title: "Introduction Draft", goal: "Write introduction section (~1000 words)", estimatedMinutes: 90),
                        SessionPlan(title: "Methods Draft", goal: "Write methodology section (~1500 words)", estimatedMinutes: 90),
                        SessionPlan(title: "Results Draft", goal: "Draft results section with placeholder figures", estimatedMinutes: 90),
                        SessionPlan(title: "Discussion Draft", goal: "Write discussion section (~1200 words)", estimatedMinutes: 90)
                    ]
                ),
                PhasePlan(
                    name: "Refining",
                    sessions: [
                        SessionPlan(title: "Flow Polish", goal: "Edit for clarity and smooth transitions", estimatedMinutes: 90),
                        SessionPlan(title: "Citation Cleanup", goal: "Format all citations and references", estimatedMinutes: 60),
                        SessionPlan(title: "Final Review", goal: "Read aloud and fix remaining issues", estimatedMinutes: 75)
                    ]
                )
            ]
        )
    }
}
