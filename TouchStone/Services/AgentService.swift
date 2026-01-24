import Foundation
import Combine
import SwiftData

/// Service for communicating with the TouchStone Agent Backend.
/// Handles conversational AI interactions using the Stones & Water philosophy.
@MainActor
class AgentService: ObservableObject {

    // MARK: - Types

    enum AgentError: Error, LocalizedError {
        case noBackendURL
        case invalidResponse
        case httpError(Int, String?)
        case decodingError(String)
        case networkError(Error)
        case streamingError(String)

        var errorDescription: String? {
            switch self {
            case .noBackendURL:
                return "Backend URL not configured. Please set the agent backend URL in Settings."
            case .invalidResponse:
                return "Invalid response from agent backend."
            case .httpError(let code, let message):
                return "HTTP Error \(code): \(message ?? "Unknown error")"
            case .decodingError(let message):
                return "Failed to parse response: \(message)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .streamingError(let message):
                return "Streaming error: \(message)"
            }
        }
    }

    // MARK: - Request/Response Models

    struct ChatRequest: Codable {
        let message: String
        let sessionId: String?
        let context: UserContext?

        enum CodingKeys: String, CodingKey {
            case message
            case sessionId = "session_id"
            case context
        }
    }

    struct UserContext: Codable {
        let today: String
        let currentTime: String?
        let projects: [ProjectSummary]
        let stonesToday: [StoneSummary]
        let freeHoursToday: Double
        let documentContexts: [DocumentContext]
        let dayContexts: [DayContextSummary]

        enum CodingKeys: String, CodingKey {
            case today
            case currentTime = "current_time"
            case projects
            case stonesToday = "stones_today"
            case freeHoursToday = "free_hours_today"
            case documentContexts = "document_contexts"
            case dayContexts = "day_contexts"
        }

        init(
            today: String,
            currentTime: String?,
            projects: [ProjectSummary],
            stonesToday: [StoneSummary],
            freeHoursToday: Double,
            documentContexts: [DocumentContext] = [],
            dayContexts: [DayContextSummary] = []
        ) {
            self.today = today
            self.currentTime = currentTime
            self.projects = projects
            self.stonesToday = stonesToday
            self.freeHoursToday = freeHoursToday
            self.documentContexts = documentContexts
            self.dayContexts = dayContexts
        }
    }

    struct ProjectSummary: Codable {
        let id: String
        let title: String
        let progress: Double
        let deadline: String?
    }

    struct StoneSummary: Codable {
        let id: String
        let title: String
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int

        enum CodingKeys: String, CodingKey {
            case id, title
            case startHour = "start_hour"
            case startMinute = "start_minute"
            case endHour = "end_hour"
            case endMinute = "end_minute"
        }
    }

    struct DocumentContext: Codable {
        let filename: String
        let extractedText: String

        enum CodingKeys: String, CodingKey {
            case filename
            case extractedText = "extracted_text"
        }
    }

    struct DayContextSummary: Codable {
        let name: String
        let type: String           // holiday, vacation, travel, event, personal, custom
        let workMode: String       // none, reduced, fixed, normal
        let capacityPercent: Int   // 0-100
        let fixedTaskDescription: String?

        enum CodingKeys: String, CodingKey {
            case name, type
            case workMode = "work_mode"
            case capacityPercent = "capacity_percent"
            case fixedTaskDescription = "fixed_task_description"
        }
    }

    // MARK: - Conversation State (Phase 2)

    enum ConversationState: String, Codable {
        case initial
        case refining
        case confirmed
        case cancelled
    }

    // MARK: - Pending Actions (Phase 2)

    struct PendingStone: Codable, Identifiable {
        let tempId: String
        let title: String
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int
        let date: String?
        let isRecurring: Bool
        let recurrenceType: String?
        let customDays: [Int]?

        var id: String { tempId }

        var timeRangeString: String {
            String(format: "%d:%02d - %d:%02d", startHour, startMinute, endHour, endMinute)
        }

        // Memberwise initializer
        init(
            tempId: String,
            title: String,
            startHour: Int,
            startMinute: Int,
            endHour: Int,
            endMinute: Int,
            date: String? = nil,
            isRecurring: Bool = false,
            recurrenceType: String? = nil,
            customDays: [Int]? = nil
        ) {
            self.tempId = tempId
            self.title = title
            self.startHour = startHour
            self.startMinute = startMinute
            self.endHour = endHour
            self.endMinute = endMinute
            self.date = date
            self.isRecurring = isRecurring
            self.recurrenceType = recurrenceType
            self.customDays = customDays
        }

        enum CodingKeys: String, CodingKey {
            case tempId = "temp_id"
            case title
            case startHour = "start_hour"
            case startMinute = "start_minute"
            case endHour = "end_hour"
            case endMinute = "end_minute"
            case date
            case isRecurring = "is_recurring"
            case recurrenceType = "recurrence_type"
            case customDays = "custom_days"
        }
    }

    struct PendingPhase: Codable {
        let title: String
        let phaseType: String
        let mentalRule: String
        let estimatedMinutes: Int

        init(title: String, phaseType: String, mentalRule: String, estimatedMinutes: Int) {
            self.title = title
            self.phaseType = phaseType
            self.mentalRule = mentalRule
            self.estimatedMinutes = estimatedMinutes
        }

        enum CodingKeys: String, CodingKey {
            case title
            case phaseType = "phase_type"
            case mentalRule = "mental_rule"
            case estimatedMinutes = "estimated_minutes"
        }
    }

    struct PendingMilestone: Codable {
        let title: String
        let description: String?
        let sequenceOrder: Int
        let estimatedMinutes: Int

        init(title: String, description: String? = nil, sequenceOrder: Int, estimatedMinutes: Int = 60) {
            self.title = title
            self.description = description
            self.sequenceOrder = sequenceOrder
            self.estimatedMinutes = estimatedMinutes
        }

        enum CodingKeys: String, CodingKey {
            case title
            case description
            case sequenceOrder = "sequence_order"
            case estimatedMinutes = "estimated_minutes"
        }

        // Decoder with default for backward compatibility
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            description = try container.decodeIfPresent(String.self, forKey: .description)
            sequenceOrder = try container.decodeIfPresent(Int.self, forKey: .sequenceOrder) ?? 0
            estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 60
        }
    }

    struct PendingProject: Codable, Identifiable {
        let tempId: String
        let title: String
        let mode: String  // "phase" or "milestone"
        let archetype: String?  // Only for phase mode
        let deadline: String?
        let totalPlannedMinutes: Int
        let phases: [PendingPhase]
        let milestones: [PendingMilestone]

        var id: String { tempId }

        var isPhaseMode: Bool { mode == "phase" }
        var isMilestoneMode: Bool { mode == "milestone" }

        enum CodingKeys: String, CodingKey {
            case tempId = "temp_id"
            case title
            case mode
            case archetype
            case deadline
            case totalPlannedMinutes = "total_planned_minutes"
            case phases
            case milestones
        }

        // Regular memberwise initializer
        init(
            tempId: String,
            title: String,
            mode: String = "phase",
            archetype: String? = nil,
            deadline: String? = nil,
            totalPlannedMinutes: Int = 0,
            phases: [PendingPhase] = [],
            milestones: [PendingMilestone] = []
        ) {
            self.tempId = tempId
            self.title = title
            self.mode = mode
            self.archetype = archetype
            self.deadline = deadline
            self.totalPlannedMinutes = totalPlannedMinutes
            self.phases = phases
            self.milestones = milestones
        }

        // Provide defaults for backward compatibility
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tempId = try container.decode(String.self, forKey: .tempId)
            title = try container.decode(String.self, forKey: .title)
            mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "phase"
            archetype = try container.decodeIfPresent(String.self, forKey: .archetype)
            deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
            totalPlannedMinutes = try container.decodeIfPresent(Int.self, forKey: .totalPlannedMinutes) ?? 0
            phases = try container.decodeIfPresent([PendingPhase].self, forKey: .phases) ?? []
            milestones = try container.decodeIfPresent([PendingMilestone].self, forKey: .milestones) ?? []
        }
    }

    struct PendingTouchLog: Codable, Identifiable {
        let tempId: String
        let projectId: String?
        let projectTitle: String?
        let durationMinutes: Int
        let note: String?

        var id: String { tempId }

        // Memberwise initializer
        init(
            tempId: String,
            projectId: String? = nil,
            projectTitle: String? = nil,
            durationMinutes: Int,
            note: String? = nil
        ) {
            self.tempId = tempId
            self.projectId = projectId
            self.projectTitle = projectTitle
            self.durationMinutes = durationMinutes
            self.note = note
        }

        enum CodingKeys: String, CodingKey {
            case tempId = "temp_id"
            case projectId = "project_id"
            case projectTitle = "project_title"
            case durationMinutes = "duration_minutes"
            case note
        }
    }

    struct PendingAction: Codable, Identifiable {
        let actionType: String
        let stone: PendingStone?
        let project: PendingProject?
        let touchLog: PendingTouchLog?

        var id: String {
            stone?.id ?? project?.id ?? touchLog?.id ?? UUID().uuidString
        }

        // Memberwise initializer
        init(
            actionType: String,
            stone: PendingStone? = nil,
            project: PendingProject? = nil,
            touchLog: PendingTouchLog? = nil
        ) {
            self.actionType = actionType
            self.stone = stone
            self.project = project
            self.touchLog = touchLog
        }

        enum CodingKeys: String, CodingKey {
            case actionType = "action_type"
            case stone
            case project
            case touchLog = "touch_log"
        }
    }

    struct ChatResponse: Codable {
        let message: String
        let sessionId: String

        // Phase 2: Pending actions for GenUI preview
        let pendingActions: [PendingAction]
        let confirmedActions: [PendingAction]  // Actions just confirmed (for multi-task flow)
        let confirmationRequired: Bool
        let conversationState: ConversationState

        // Quick reply suggestions
        let suggestions: [String]

        // Legacy support
        let actions: [AgentAction]
        let suggestedFollowup: String?

        enum CodingKeys: String, CodingKey {
            case message
            case sessionId = "session_id"
            case pendingActions = "pending_actions"
            case confirmedActions = "confirmed_actions"
            case confirmationRequired = "confirmation_required"
            case conversationState = "conversation_state"
            case suggestions
            case actions
            case suggestedFollowup = "suggested_followup"
        }

        // Provide defaults for backward compatibility
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            message = try container.decode(String.self, forKey: .message)
            sessionId = try container.decode(String.self, forKey: .sessionId)
            pendingActions = try container.decodeIfPresent([PendingAction].self, forKey: .pendingActions) ?? []
            confirmedActions = try container.decodeIfPresent([PendingAction].self, forKey: .confirmedActions) ?? []
            confirmationRequired = try container.decodeIfPresent(Bool.self, forKey: .confirmationRequired) ?? false
            conversationState = try container.decodeIfPresent(ConversationState.self, forKey: .conversationState) ?? .initial
            suggestions = try container.decodeIfPresent([String].self, forKey: .suggestions) ?? []
            actions = try container.decodeIfPresent([AgentAction].self, forKey: .actions) ?? []
            suggestedFollowup = try container.decodeIfPresent(String.self, forKey: .suggestedFollowup)
        }
    }

    struct AgentAction: Codable, Identifiable {
        let agent: String
        let actionType: String
        let description: String
        let data: [String: AnyCodable]?

        var id: String { "\(agent)-\(actionType)-\(description)" }

        enum CodingKeys: String, CodingKey {
            case agent
            case actionType = "action_type"
            case description
            case data
        }
    }

    struct DailyBriefing: Codable {
        let greeting: String
        let stonesToday: [StoneSummary]
        let freeHours: Double
        let suggestedFocus: String?
        let activeProjectsSummary: [[String: AnyCodable]]
        let nudge: String?

        enum CodingKeys: String, CodingKey {
            case greeting
            case stonesToday = "stones_today"
            case freeHours = "free_hours"
            case suggestedFocus = "suggested_focus"
            case activeProjectsSummary = "active_projects_summary"
            case nudge
        }
    }

    // MARK: - Properties

    /// The base URL for the agent backend
    /// Uses localhost only in simulator, production URL for physical devices and release builds
    private var baseURL: String {
        #if DEBUG && targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        return "https://touchstone-agent-backend.fly.dev"
        #endif
    }

    /// Current session ID for conversation continuity
    @Published private(set) var sessionId: String?

    /// Whether a request is currently in progress
    @Published private(set) var isLoading = false

    /// The last error that occurred
    @Published private(set) var lastError: AgentError?

    /// Accumulated response during streaming
    @Published private(set) var streamingResponse = ""

    // MARK: - Singleton

    static let shared = AgentService()

    private init() {}

    // MARK: - Chat

    /// Send a message to the agent and get a response.
    func chat(message: String, context: UserContext? = nil) async throws -> ChatResponse {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let url = URL(string: "\(baseURL)/chat")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let chatRequest = ChatRequest(
            message: message,
            sessionId: sessionId,
            context: context
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            let agentError = AgentError.networkError(error)
            lastError = agentError
            throw agentError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            let agentError = AgentError.invalidResponse
            lastError = agentError
            throw agentError
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8)
            let agentError = AgentError.httpError(httpResponse.statusCode, errorMessage)
            lastError = agentError
            throw agentError
        }

        do {
            let decoder = JSONDecoder()
            let chatResponse = try decoder.decode(ChatResponse.self, from: data)
            sessionId = chatResponse.sessionId
            return chatResponse
        } catch {
            let agentError = AgentError.decodingError(String(describing: error))
            lastError = agentError
            throw agentError
        }
    }

    /// Stream a chat response using Server-Sent Events.
    func chatStream(message: String) -> AsyncThrowingStream<String, Error> {
        // Capture values before creating the stream
        let currentSessionId = self.sessionId
        let urlBase = self.baseURL

        // Reset state
        self.isLoading = true
        self.lastError = nil
        self.streamingResponse = ""

        return AsyncThrowingStream { continuation in
            Task {
                var urlComponents = URLComponents(string: "\(urlBase)/chat/stream")!
                urlComponents.queryItems = [
                    URLQueryItem(name: "message", value: message)
                ]
                if let sessionId = currentSessionId {
                    urlComponents.queryItems?.append(URLQueryItem(name: "session_id", value: sessionId))
                }

                guard let url = urlComponents.url else {
                    continuation.finish(throwing: AgentError.invalidResponse)
                    return
                }

                var request = URLRequest(url: url)
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: AgentError.invalidResponse)
                        return
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if let data = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                                if let text = json["text"] as? String {
                                    await MainActor.run {
                                        self.streamingResponse += text
                                    }
                                    continuation.yield(text)
                                }

                                if json["done"] as? Bool == true {
                                    if let newSessionId = json["session_id"] as? String {
                                        await MainActor.run {
                                            self.sessionId = newSessionId
                                        }
                                    }
                                    break
                                }
                            }
                        }
                    }

                    await MainActor.run {
                        self.isLoading = false
                    }
                    continuation.finish()

                } catch {
                    await MainActor.run {
                        self.isLoading = false
                        self.lastError = .networkError(error)
                    }
                    continuation.finish(throwing: AgentError.networkError(error))
                }
            }
        }
    }

    // MARK: - Daily Briefing

    /// Get the daily briefing.
    func getDailyBriefing() async throws -> DailyBriefing {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let url = URL(string: "\(baseURL)/briefing")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            let agentError = AgentError.networkError(error)
            lastError = agentError
            throw agentError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            let agentError = AgentError.invalidResponse
            lastError = agentError
            throw agentError
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8)
            let agentError = AgentError.httpError(httpResponse.statusCode, errorMessage)
            lastError = agentError
            throw agentError
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(DailyBriefing.self, from: data)
        } catch {
            let agentError = AgentError.decodingError(String(describing: error))
            lastError = agentError
            throw agentError
        }
    }

    // MARK: - Session Management

    /// Start a new conversation session.
    func startNewSession() {
        sessionId = nil
        streamingResponse = ""
        lastError = nil
    }

    // MARK: - Health Check

    /// Check if the backend is reachable.
    func healthCheck() async -> Bool {
        let url = URL(string: "\(baseURL)/health")!

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - AnyCodable Helper

/// A type-erased Codable value for handling arbitrary JSON.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: container.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

// MARK: - Context Building Extension

extension AgentService {

    /// Build context from SwiftData models.
    /// Call this from views that have access to the model context.
    /// - Parameters:
    ///   - projects: Active projects to include in context
    ///   - stonesForToday: Today's stone events
    ///   - freeHours: Available hours today
    ///   - documents: Documents attached to the current message
    ///   - focusedProject: Optional project being discussed - its documents will be included
    ///   - dayContexts: Day contexts (holidays, vacations, etc.) affecting today's scheduling
    static func buildContext(
        projects: [Project],
        stonesForToday: [StoneEvent],
        freeHours: Double,
        documents: [DocumentContext] = [],
        focusedProject: Project? = nil,
        dayContexts: [DayContext] = []
    ) -> UserContext {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        let projectSummaries = projects.prefix(10).map { project in
            ProjectSummary(
                id: project.id.uuidString,
                title: project.title,
                progress: project.progress,
                deadline: project.deadline.map { dateFormatter.string(from: $0) }
            )
        }

        let stoneSummaries = stonesForToday.map { stone in
            StoneSummary(
                id: stone.id.uuidString,
                title: stone.title,
                startHour: stone.startHour,
                startMinute: stone.startMinute,
                endHour: stone.endHour,
                endMinute: stone.endMinute
            )
        }

        // Combine attached documents with focused project documents
        var allDocuments = documents

        // Add documents from focused project if available
        if let focused = focusedProject {
            for projectDoc in focused.documents {
                if let text = projectDoc.extractedText, !text.isEmpty {
                    let docContext = DocumentContext(
                        filename: "[Project: \(focused.title)] \(projectDoc.filename)",
                        extractedText: String(text.prefix(15000))
                    )
                    allDocuments.append(docContext)
                }
            }
        }

        // Convert DayContext models to summaries for today
        let today = Date()
        let dayContextSummaries = dayContexts
            .filter { $0.appliesTo(date: today) }
            .map { context in
                DayContextSummary(
                    name: context.name,
                    type: context.type.rawValue,
                    workMode: context.workMode.rawValue,
                    capacityPercent: context.capacityPercent,
                    fixedTaskDescription: context.fixedTaskDescription
                )
            }

        return UserContext(
            today: dateFormatter.string(from: Date()),
            currentTime: timeFormatter.string(from: Date()),
            projects: Array(projectSummaries),
            stonesToday: stoneSummaries,
            freeHoursToday: freeHours,
            documentContexts: allDocuments,
            dayContexts: dayContextSummaries
        )
    }
}
