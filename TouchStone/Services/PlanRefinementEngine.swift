import Foundation

/// AI-powered engine for refining existing strategic plans.
/// Handles plan modifications while preserving completed work.
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
        let sessions: [SessionPlan]
    }

    struct SessionPlan: Codable {
        let title: String
        let goal: String
        let estimatedMinutes: Int
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

        // Build locked sessions description
        let lockedSessionsDesc = buildLockedSessionsDescription(project)

        // Build regenerable sessions description
        let regenerableDesc = buildRegenerableSessionsDescription(project)

        // Build document context
        let documentContext = buildDocumentContext(context)

        // Build phase structure
        let phaseStructure = buildPhaseStructureDescription(project)

        return """
        You are a strategic planning assistant refining an existing project plan.

        PROJECT CONTEXT:
        - Title: \(project.title)
        - Archetype: \(project.archetype?.displayName ?? "Unknown")
        - Total planned time: \(project.totalPlannedMinutes) minutes (\(project.totalPlannedMinutes / 60) hours)

        CURRENT PROGRESS:
        \(project.progressSummary)

        COMPLETED SESSIONS (DO NOT MODIFY OR REMOVE - these are locked):
        \(lockedSessionsDesc)

        REMAINING PLANNED SESSIONS (can be modified):
        \(regenerableDesc)

        PHASE STRUCTURE:
        \(phaseStructure)
        \(documentContext)

        RULES:
        1. NEVER modify, remove, or reference completed/skipped sessions - they are permanently locked
        2. Only generate sessions for REMAINING work in each phase
        3. Maintain the archetype's phase structure and mental rules
        4. Session goals must be specific and actionable (e.g., "Write 1000 words" not "Write some")
        5. Each session should be 60-90 minutes
        6. Earlier sessions in a phase should build toward later ones
        7. Consider the user's request and any document context provided
        8. Provide reasoning explaining what you changed and why

        Return ONLY valid JSON matching this structure:
        {
            "phases": [
                {
                    "name": "Phase Name",
                    "sessions": [
                        {"title": "Session title", "goal": "Specific measurable goal", "estimatedMinutes": 60}
                    ]
                }
            ],
            "reasoning": "Brief explanation of changes made"
        }

        IMPORTANT: Only include phases that have REMAINING (non-completed) sessions to generate.
        If a phase is fully completed, do NOT include it in your response.
        """
    }

    private func buildLockedSessionsDescription(_ project: Project) -> String {
        let locked = project.lockedSessions
        if locked.isEmpty {
            return "None (no sessions completed yet)"
        }

        return locked.map { session in
            let status = session.status == .completed ? "COMPLETED" : "SKIPPED"
            let phase = session.phase?.title ?? "Unknown"
            return "- [\(status)] \(session.title) (Phase: \(phase))"
        }.joined(separator: "\n")
    }

    private func buildRegenerableSessionsDescription(_ project: Project) -> String {
        let regenerable = project.regenerableSessions
        if regenerable.isEmpty {
            return "None (all sessions completed)"
        }

        return regenerable.map { session in
            let phase = session.phase?.title ?? "Unknown"
            let goal = session.goal ?? "No goal specified"
            return "- \(session.title): \(goal) (~\(session.estimatedMinutes)min, Phase: \(phase))"
        }.joined(separator: "\n")
    }

    private func buildPhaseStructureDescription(_ project: Project) -> String {
        guard let archetype = project.archetype else {
            return "No archetype specified"
        }

        return archetype.phaseStructure.enumerated().map { index, template in
            let phase = project.sortedPhases.first { $0.title == template.name }
            let completedCount = phase?.sessions.filter { $0.status != .planned }.count ?? 0
            let totalCount = phase?.sessions.count ?? 0

            return """
            Phase \(index + 1): \(template.name) (\(template.type.displayName))
            - Mental Rule: "\(template.rule)"
            - Progress: \(completedCount)/\(totalCount) sessions done
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

    /// Apply refinement result to a project, preserving completed sessions
    func applyRefinement(
        to project: Project,
        result: RefinementResult
    ) -> [ProjectPhase] {
        var updatedPhases: [ProjectPhase] = []

        for (index, existingPhase) in project.sortedPhases.enumerated() {
            // Keep completed/skipped sessions
            let lockedSessions = existingPhase.sessions.filter { $0.status != .planned }

            // Find new sessions for this phase from the result
            let newSessionPlans = result.phases
                .first { $0.name == existingPhase.title }?
                .sessions ?? []

            // Create new PlannedSession objects for the regenerated sessions
            var newSessions: [PlannedSession] = []
            for (sessionIndex, plan) in newSessionPlans.enumerated() {
                let session = PlannedSession(
                    title: plan.title,
                    goal: plan.goal,
                    estimatedMinutes: plan.estimatedMinutes,
                    sequenceOrder: lockedSessions.count + sessionIndex
                )
                session.phase = existingPhase
                newSessions.append(session)
            }

            // Remove old planned sessions (will be replaced)
            let oldPlanned = existingPhase.sessions.filter { $0.status == .planned }

            // Update phase sessions
            existingPhase.sessions = lockedSessions + newSessions

            // Update sequence orders for locked sessions
            for (i, session) in lockedSessions.enumerated() {
                session.sequenceOrder = i
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
                    sessions: [
                        SessionPlan(title: "Updated Research", goal: "Focus on specific subtopic based on new context", estimatedMinutes: 75),
                        SessionPlan(title: "Competitive Analysis", goal: "Review 5 competitor approaches", estimatedMinutes: 60)
                    ]
                ),
                PhasePlan(
                    name: "Bricklaying",
                    sessions: [
                        SessionPlan(title: "Draft Outline", goal: "Create detailed outline with new structure", estimatedMinutes: 60),
                        SessionPlan(title: "First Draft", goal: "Write 2000 words following outline", estimatedMinutes: 90)
                    ]
                )
            ],
            reasoning: "Adjusted the plan to focus more on competitive analysis based on the uploaded document context. Reduced exploration sessions since initial research phase was partially completed."
        )
    }
}
