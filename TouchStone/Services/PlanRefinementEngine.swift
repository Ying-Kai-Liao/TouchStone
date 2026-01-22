import Foundation

/// AI-powered engine for refining existing strategic plans.
/// Works with phase time budgets (no sessions).
actor PlanRefinementEngine {
    private let openAI = OpenAIClient()
    private let textExtractor = DocumentTextExtractor()

    // MARK: - Refinement Context

    /// Context for plan refinement including project state and user request
    struct RefinementContext {
        let project: Project
        let userRequest: String
        let additionalDocumentTexts: [String]

        init(project: Project, userRequest: String, additionalDocumentTexts: [String] = []) {
            self.project = project
            self.userRequest = userRequest
            self.additionalDocumentTexts = additionalDocumentTexts
        }
    }

    // MARK: - Response Types

    struct RefinementResult: Codable {
        let phases: [PhasePlan]
        let reasoning: String
    }

    struct PhasePlan: Codable {
        let name: String
        let estimatedMinutes: Int
        let mentalRule: String?
    }

    // MARK: - Main Refinement

    /// Refine a project's plan based on user request and context
    func refinePlan(context: RefinementContext) async throws -> RefinementResult {
        let systemPrompt = buildRefinementPrompt(context: context)
        let userMessage = context.userRequest

        return try await openAI.chatJSON(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.7,
            responseType: RefinementResult.self
        )
    }

    // MARK: - Prompt Building

    private func buildRefinementPrompt(context: RefinementContext) -> String {
        let project = context.project

        // Build phase progress description
        let phaseProgress = buildPhaseProgressDescription(project)

        // Build document context
        let documentContext = buildDocumentContext(context)

        return """
        You are a strategic planning assistant refining an existing project plan.

        PROJECT CONTEXT:
        - Title: \(project.title)
        - Archetype: \(project.archetype?.displayName ?? "Unknown")
        - Total planned time: \(project.totalPlannedMinutes) minutes (\(project.totalPlannedMinutes / 60) hours)

        CURRENT PROGRESS:
        \(project.progressSummary)

        PHASE TIME BUDGETS:
        \(phaseProgress)
        \(documentContext)

        RULES:
        1. Maintain the archetype's phase structure
        2. Adjust time budgets based on the user's request
        3. Consider work already logged when redistributing time
        4. Mental rules guide the cognitive approach for each phase
        5. Provide reasoning explaining what you changed and why

        Return ONLY valid JSON matching this structure:
        {
            "phases": [
                {
                    "name": "Phase Name",
                    "estimatedMinutes": 120,
                    "mentalRule": "Optional new mental rule"
                }
            ],
            "reasoning": "Brief explanation of changes made"
        }

        Include ALL phases in your response, even if unchanged.
        """
    }

    private func buildPhaseProgressDescription(_ project: Project) -> String {
        return project.sortedPhases.enumerated().map { index, phase in
            let loggedMinutes = phase.touchLogs.reduce(0) { $0 + $1.durationMinutes }
            let remaining = max(0, phase.estimatedMinutes - loggedMinutes)

            return """
            Phase \(index + 1): \(phase.title)
            - Type: \(phase.phaseType.displayName)
            - Mental Rule: "\(phase.mentalRule ?? "None")"
            - Time Budget: \(phase.estimatedMinutes) minutes
            - Logged: \(loggedMinutes) minutes
            - Remaining: \(remaining) minutes
            """
        }.joined(separator: "\n\n")
    }

    private func buildDocumentContext(_ context: RefinementContext) -> String {
        var parts: [String] = []

        // Add project's stored document context
        let projectDocs = context.project.documentContext
        if !projectDocs.isEmpty {
            parts.append(projectDocs)
        }

        // Add any additional document texts
        parts.append(contentsOf: context.additionalDocumentTexts.filter { !$0.isEmpty })

        if parts.isEmpty {
            return ""
        }

        let combined = parts.joined(separator: "\n\n---\n\n")
        let truncated = truncateForContext(combined)

        return """

        DOCUMENT CONTEXT (additional information provided by user):
        \(truncated)
        """
    }

    private func truncateForContext(_ text: String, maxCharacters: Int = 30000) -> String {
        guard text.count > maxCharacters else { return text }

        let truncated = String(text.prefix(maxCharacters))
        if let lastPeriod = truncated.lastIndex(of: ".") {
            return String(truncated[...lastPeriod]) + "\n[Truncated for length]"
        }
        return truncated + "\n[Truncated for length]"
    }

    // MARK: - Apply Refinement

    /// Apply refinement result to a project, updating phase time budgets
    func applyRefinement(
        to project: Project,
        result: RefinementResult
    ) -> [ProjectPhase] {
        var updatedPhases: [ProjectPhase] = []

        for existingPhase in project.sortedPhases {
            // Find the corresponding phase in the result
            if let phasePlan = result.phases.first(where: { $0.name == existingPhase.title }) {
                // Update time budget
                existingPhase.estimatedMinutes = phasePlan.estimatedMinutes

                // Update mental rule if provided
                if let newRule = phasePlan.mentalRule, !newRule.isEmpty {
                    existingPhase.mentalRule = newRule
                }
            }

            updatedPhases.append(existingPhase)
        }

        // Update project's last modified timestamp
        project.lastPlanModifiedAt = Date()

        return updatedPhases
    }
}

// MARK: - Mock Data for Previews

extension PlanRefinementEngine {
    static func mockRefinementResult() -> RefinementResult {
        RefinementResult(
            phases: [
                PhasePlan(
                    name: "Exploration",
                    estimatedMinutes: 180,
                    mentalRule: "Divergent thinking - explore widely"
                ),
                PhasePlan(
                    name: "Bricklaying",
                    estimatedMinutes: 240,
                    mentalRule: "Iterative progress - build steadily"
                )
            ],
            reasoning: "Adjusted the plan to allocate more time to the execution phase based on the user's feedback that they need more time for detailed implementation."
        )
    }
}
