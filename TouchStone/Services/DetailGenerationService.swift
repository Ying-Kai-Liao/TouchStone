import Foundation

/// Service for generating practical, actionable details for sessions on-demand.
/// This is the "magic button" that helps users who feel unmotivated by breaking
/// abstract tasks into concrete, bite-sized steps.
actor DetailGenerationService {
    private let openAI = OpenAIClient()

    struct GeneratedDetails: Codable {
        let steps: [Step]
        let tip: String?

        struct Step: Codable {
            let action: String
            let timeEstimate: String?
        }
    }

    /// Generates practical breakdown steps for a session.
    /// Uses session title, goal, phase context, and mental rule to create
    /// actionable, motivating micro-steps.
    func generateDetails(
        sessionTitle: String,
        sessionGoal: String?,
        phaseName: String?,
        mentalRule: String?,
        projectTitle: String?
    ) async throws -> String {
        let systemPrompt = """
        You are a productivity coach helping someone who feels stuck or unmotivated.
        Your job is to break down a work session into small, practical, actionable steps.

        PRINCIPLES:
        - Make each step feel achievable (2-10 minutes each)
        - Start with the easiest "warmup" step to build momentum
        - Be specific and concrete, not abstract
        - Include physical actions when possible ("Open X", "Write down", "Search for")
        - Keep the mental rule in mind - it defines HOW to approach the work
        - End with a small reward or checkpoint

        FORMAT:
        Return JSON with this structure:
        {
            "steps": [
                {"action": "Do this specific thing", "timeEstimate": "2 min"},
                {"action": "Then do this", "timeEstimate": "5 min"}
            ],
            "tip": "Optional quick motivation tip based on the mental rule"
        }

        Generate 4-7 steps that feel doable and build momentum.
        Keep each action to ONE sentence, under 15 words.
        """

        var context = "Session: \(sessionTitle)"
        if let goal = sessionGoal, !goal.isEmpty {
            context += "\nGoal: \(goal)"
        }
        if let phase = phaseName {
            context += "\nPhase: \(phase)"
        }
        if let rule = mentalRule {
            context += "\nMental Rule: \"\(rule)\""
        }
        if let project = projectTitle {
            context += "\nProject: \(project)"
        }

        let userMessage = """
        Break this session into practical micro-steps that feel easy to start:

        \(context)
        """

        let response = try await openAI.chatJSON(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.7,
            responseType: GeneratedDetails.self
        )

        return formatDetails(response)
    }

    /// Formats the generated details into a readable string for storage/display
    private func formatDetails(_ details: GeneratedDetails) -> String {
        var result = ""

        for (index, step) in details.steps.enumerated() {
            let timeStr = step.timeEstimate.map { " (\($0))" } ?? ""
            result += "\(index + 1). \(step.action)\(timeStr)\n"
        }

        if let tip = details.tip, !tip.isEmpty {
            result += "\n\(tip)"
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
