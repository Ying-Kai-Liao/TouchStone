import SwiftUI
import SwiftData

/// Unified conversational input view for AI-powered productivity assistance.
/// Users can type or speak naturally, and the AI routes to appropriate actions.
struct UnifiedInputView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var agentService = AgentService.shared

    @Query(filter: #Predicate<Project> { $0.isActive }, sort: \Project.createdAt, order: .reverse)
    private var activeProjects: [Project]

    @Query private var allStones: [StoneEvent]

    // MARK: - State

    @State private var inputText = ""
    @State private var messages: [AgentChatMessage] = []
    @State private var showingSpeechInput = false
    @State private var isBackendAvailable = false
    @State private var briefing: AgentService.DailyBriefing?
    @State private var errorMessage: String?

    // Phase 2: Pending actions state
    @State private var pendingActions: [AgentService.PendingAction] = []
    @State private var suggestions: [String] = []
    @State private var conversationState: AgentService.ConversationState = .initial

    // Confirmed actions (displayed after commit)
    @State private var confirmedActions: [AgentService.PendingAction] = []
    @State private var confirmedActionsClearTask: DispatchWorkItem?

    @SwiftUI.FocusState private var isInputFocused: Bool

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Messages scroll view
                    messagesView

                    // Input bar
                    inputBar
                }
            }
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewSession()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .task {
                await checkBackendAndLoadBriefing()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Messages View

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.md) {
                    // Briefing card if available
                    if let briefing = briefing, messages.isEmpty {
                        BriefingCard(briefing: briefing)
                            .padding(.horizontal)
                            .padding(.top)
                    }

                    // Placeholder when no messages
                    if messages.isEmpty && briefing == nil {
                        emptyStateView
                    }

                    // Chat messages
                    ForEach(messages) { message in
                        AgentMessageBubble(message: message)
                            .padding(.horizontal)
                            .id(message.id)
                    }

                    // Pending actions preview (Phase 2) - show when waiting for confirmation
                    if !pendingActions.isEmpty && (conversationState == .initial || conversationState == .refining) {
                        PendingActionsPreview(
                            pendingActions: pendingActions,
                            suggestions: suggestions,
                            onConfirm: {
                                confirmPendingActions()
                            },
                            onCancel: {
                                cancelPendingActions()
                            },
                            onSuggestionTap: { suggestion in
                                sendMessage(suggestion)
                            },
                            onProjectTimeChange: { projectId, newMinutes in
                                updateProjectTime(projectId: projectId, newMinutes: newMinutes)
                            },
                            onActionUpdate: { index, updatedAction in
                                updatePendingAction(at: index, with: updatedAction)
                            },
                            onActionDelete: { index in
                                deletePendingAction(at: index)
                            },
                            availableProjects: activeProjects.map {
                                PendingLogDetailSheet.ProjectOption(id: $0.id.uuidString, title: $0.title)
                            }
                        )
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id("pending-actions")
                    }

                    // Confirmed actions preview (shown after user confirms)
                    if !confirmedActions.isEmpty {
                        ConfirmedActionsPreview(confirmedActions: confirmedActions)
                            .padding(.horizontal)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .id("confirmed-actions")
                    }

                    // Streaming response
                    if agentService.isLoading && !agentService.streamingResponse.isEmpty {
                        AgentMessageBubble(message: AgentChatMessage(
                            role: .assistant,
                            content: agentService.streamingResponse
                        ))
                        .padding(.horizontal)
                        .id("streaming")
                    }

                    // Loading indicator
                    if agentService.isLoading && agentService.streamingResponse.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        .padding()
                        .id("loading")
                    }

                    // Suggestions while connected (shown when messages exist and no pending actions)
                    if !messages.isEmpty && pendingActions.isEmpty && isBackendAvailable && !agentService.isLoading {
                        connectedSuggestionsView
                            .padding(.horizontal)
                            .padding(.top, DesignSystem.Spacing.sm)
                            .id("connected-suggestions")
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .onChange(of: messages.count) {
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: agentService.streamingResponse) {
                withAnimation {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("What's on your mind?")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                SuggestionChip(text: "I want to write a book", icon: "doc.text") {
                    sendMessage("I want to write a book")
                }
                SuggestionChip(text: "Meeting at 3pm", icon: "calendar.badge.plus") {
                    sendMessage("I have a meeting at 3pm")
                }
                SuggestionChip(text: "What should I work on?", icon: "questionmark.circle") {
                    sendMessage("What should I work on?")
                }
                SuggestionChip(text: "Worked 1 hour on my project", icon: "checkmark.circle") {
                    sendMessage("I worked for an hour on my project")
                }
            }
            .padding(.top)

            if !isBackendAvailable {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "wifi.slash")
                    Text("Backend not available")
                }
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .padding(.top)
            }

            Spacer()
        }
    }

    /// Suggestions shown when connected with existing messages
    private var connectedSuggestionsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                CompactSuggestionChip(text: "New project", icon: "folder.badge.plus") {
                    sendMessage("I want to start a new project")
                }
                CompactSuggestionChip(text: "Add event", icon: "calendar.badge.plus") {
                    sendMessage("I have an event to add")
                }
                CompactSuggestionChip(text: "Log work", icon: "checkmark.circle") {
                    sendMessage("I want to log some work")
                }
                CompactSuggestionChip(text: "What's next?", icon: "arrow.forward.circle") {
                    sendMessage("What should I work on next?")
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: DesignSystem.Spacing.md) {
                // Text field
                TextField("What's on your mind?", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                    .focused($isInputFocused)
                    .onSubmit {
                        if !inputText.isEmpty {
                            sendMessage(inputText)
                        }
                    }

                // Voice input button
                Button {
                    showingSpeechInput = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.cardBackground)
                        )
                }

                // Send button
                Button {
                    sendMessage(inputText)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(inputText.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent)
                }
                .disabled(inputText.isEmpty || agentService.isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingSpeechInput) {
            SpeechInputSheet { transcribedText in
                inputText = transcribedText
                sendMessage(transcribedText)
            }
        }
    }

    // MARK: - Actions

    private func checkBackendAndLoadBriefing() async {
        isBackendAvailable = await agentService.healthCheck()

        if isBackendAvailable {
            do {
                briefing = try await agentService.getDailyBriefing()
            } catch {
                // Briefing is optional, don't show error
                print("Failed to load briefing: \(error)")
            }
        }
    }

    private func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }

        let userMessage = AgentChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isInputFocused = false

        Task {
            do {
                // Build context from current data
                let context = buildContext()

                // Send to backend
                let response = try await agentService.chat(message: text, context: context)

                // Add assistant response
                let assistantMessage = AgentChatMessage(role: .assistant, content: response.message)
                messages.append(assistantMessage)

                // Update Phase 2 state
                pendingActions = response.pendingActions
                suggestions = response.suggestions
                conversationState = response.conversationState

                // Handle confirmed actions from backend (multi-task flow)
                if !response.confirmedActions.isEmpty {
                    // Commit to local storage
                    await commitActions(response.confirmedActions)

                    // Cancel any pending clear task from previous confirmation
                    confirmedActionsClearTask?.cancel()

                    // Show confirmed preview
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        confirmedActions = response.confirmedActions
                    }

                    // Schedule clear after delay (user can add more)
                    let clearTask = DispatchWorkItem {
                        withAnimation {
                            self.confirmedActions = []
                        }
                    }
                    confirmedActionsClearTask = clearTask
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: clearTask)
                }

                // Process any legacy actions
                await processActions(response.actions)

            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func buildContext() -> AgentService.UserContext {
        let stonesForToday = allStones.filter { $0.occursOn(date: Date()) }

        // Simple free hours calculation
        let stoneMinutes = stonesForToday.reduce(0) { total, stone in
            let startMinutes = stone.startHour * 60 + stone.startMinute
            let endMinutes = stone.endHour * 60 + stone.endMinute
            return total + max(0, endMinutes - startMinutes)
        }
        let freeHours = max(0, 8.0 - Double(stoneMinutes) / 60.0)

        return AgentService.buildContext(
            projects: Array(activeProjects),
            stonesForToday: stonesForToday,
            freeHours: freeHours
        )
    }

    private func processActions(_ actions: [AgentService.AgentAction]) async {
        for action in actions {
            switch action.actionType {
            case "add_stone":
                // Stone was already added on backend; for now, we'd need to sync
                // In production, this would trigger a sync or local insert
                print("Backend added stone: \(action.description)")

            case "log_work":
                // Work was logged on backend; we'd sync this too
                print("Backend logged work: \(action.description)")

            default:
                print("Unknown action: \(action.actionType)")
            }
        }
    }

    // MARK: - Phase 2: Pending Actions

    /// User confirmed pending actions - send confirmation to backend
    /// Uses optimistic UI: hides genui block immediately, restores on failure
    private func confirmPendingActions() {
        // Store pending actions before clearing (for potential rollback)
        let actionsToConfirm = pendingActions

        // Optimistic UI: Hide genui block immediately
        withAnimation(.easeOut(duration: 0.2)) {
            pendingActions = []
            suggestions = []
        }

        // Send confirmation message
        let userMessage = AgentChatMessage(role: .user, content: "Looks good")
        messages.append(userMessage)
        inputText = ""
        isInputFocused = false

        Task {
            do {
                let context = buildContext()
                let response = try await agentService.chat(message: "Looks good", context: context)

                // Add assistant response
                let assistantMessage = AgentChatMessage(role: .assistant, content: response.message)
                messages.append(assistantMessage)

                // Update state from response
                pendingActions = response.pendingActions
                self.suggestions = response.suggestions
                conversationState = response.conversationState

                // Handle confirmed actions from backend (multi-task flow)
                if !response.confirmedActions.isEmpty {
                    // Commit to local storage
                    await commitActions(response.confirmedActions)

                    // Cancel any pending clear task from previous confirmation
                    confirmedActionsClearTask?.cancel()

                    // Show confirmed preview
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        confirmedActions = response.confirmedActions
                    }

                    // Schedule clear after delay (user can add more)
                    let clearTask = DispatchWorkItem {
                        withAnimation {
                            self.confirmedActions = []
                        }
                    }
                    confirmedActionsClearTask = clearTask
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: clearTask)
                }
            } catch {
                // Rollback on failure: restore the pending actions
                withAnimation(.easeIn(duration: 0.2)) {
                    pendingActions = actionsToConfirm
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    /// User cancelled pending actions
    private func cancelPendingActions() {
        pendingActions = []
        suggestions = []
        conversationState = .initial
        sendMessage("Cancel")
    }

    /// Update the total time for a pending project (proportionally scales phases/milestones)
    private func updateProjectTime(projectId: String, newMinutes: Int) {
        guard let index = pendingActions.firstIndex(where: { $0.project?.id == projectId }),
              let oldProject = pendingActions[index].project else {
            return
        }

        // Calculate scaling factor
        let oldTotal = max(oldProject.totalPlannedMinutes, 1)
        let scaleFactor = Double(newMinutes) / Double(oldTotal)

        // Scale each phase proportionally
        let scaledPhases = oldProject.phases.map { phase in
            AgentService.PendingPhase(
                title: phase.title,
                phaseType: phase.phaseType,
                mentalRule: phase.mentalRule,
                estimatedMinutes: max(30, Int(Double(phase.estimatedMinutes) * scaleFactor))
            )
        }

        // Scale each milestone proportionally
        let scaledMilestones = oldProject.milestones.map { milestone in
            AgentService.PendingMilestone(
                title: milestone.title,
                description: milestone.description,
                sequenceOrder: milestone.sequenceOrder,
                estimatedMinutes: max(15, Int(Double(milestone.estimatedMinutes) * scaleFactor))
            )
        }

        // Create updated project with new times
        let updatedProject = AgentService.PendingProject(
            tempId: oldProject.tempId,
            title: oldProject.title,
            mode: oldProject.mode,
            archetype: oldProject.archetype,
            deadline: oldProject.deadline,
            totalPlannedMinutes: newMinutes,
            phases: scaledPhases,
            milestones: scaledMilestones
        )

        // Update the action
        pendingActions[index] = AgentService.PendingAction(
            actionType: pendingActions[index].actionType,
            stone: nil,
            project: updatedProject,
            touchLog: nil
        )
    }

    /// Update a pending action at a specific index (called from detail sheets)
    private func updatePendingAction(at index: Int, with updatedAction: AgentService.PendingAction) {
        guard index >= 0 && index < pendingActions.count else { return }
        pendingActions[index] = updatedAction
    }

    /// Delete a pending action at a specific index (called from detail sheets)
    private func deletePendingAction(at index: Int) {
        guard index >= 0 && index < pendingActions.count else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            pendingActions.remove(at: index)
        }
    }

    /// Create SwiftData objects from pending actions (iOS-as-authority pattern)
    /// This version uses the current pendingActions state
    private func commitPendingActions() async {
        // Store actions for confirmed preview before processing
        let actionsToConfirm = pendingActions

        // Commit the actions
        await commitActions(actionsToConfirm)

        // Clear pending state
        pendingActions = []
        suggestions = []
        conversationState = .initial

        // Show confirmed actions preview
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            confirmedActions = actionsToConfirm
        }
    }

    /// Create SwiftData objects from a list of actions (used by both commitPendingActions and direct confirmed actions)
    private func commitActions(_ actions: [AgentService.PendingAction]) async {
        for action in actions {
            switch action.actionType {
            case "add_stone":
                if let stone = action.stone {
                    await createStoneEvent(from: stone)
                }
            case "add_project":
                if let project = action.project {
                    await createProject(from: project)
                }
            case "log_work":
                if let log = action.touchLog {
                    await createTouchLog(from: log)
                }
            default:
                break
            }
        }
    }

    /// Create a StoneEvent from pending data
    private func createStoneEvent(from pending: AgentService.PendingStone) async {
        print("DEBUG: createStoneEvent - title: \(pending.title), date: \(pending.date ?? "nil")")

        let stone = StoneEvent(
            title: pending.title,
            startHour: pending.startHour,
            startMinute: pending.startMinute,
            endHour: pending.endHour,
            endMinute: pending.endMinute
        )

        // Set date for one-time events
        if let dateStr = pending.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateStr) {
                stone.specificDate = date
                print("DEBUG: Set specificDate to \(date)")
            } else {
                print("DEBUG: Failed to parse date string: \(dateStr)")
            }
        }

        // Set recurrence for recurring events
        if pending.isRecurring, let recurrenceType = pending.recurrenceType {
            switch recurrenceType.lowercased() {
            case "daily":
                stone.recurrence = .daily
            case "weekdays":
                stone.recurrence = .weekdays
            case "weekends":
                stone.recurrence = .weekends
            case "weekly":
                stone.recurrence = .weekly
            case "custom":
                if let days = pending.customDays {
                    stone.recurrence = .custom(days: days)
                }
            default:
                stone.recurrence = .none
            }
        }

        modelContext.insert(stone)
        print("DEBUG: Inserted stone into modelContext")

        do {
            try modelContext.save()
            print("DEBUG: Successfully saved stone to SwiftData")
        } catch {
            print("DEBUG: Failed to save stone: \(error)")
        }
    }

    /// Create a Project from pending data
    private func createProject(from pending: AgentService.PendingProject) async {
        let project = Project(title: pending.title)
        project.planningContext = pending.title
        project.totalPlannedMinutes = pending.totalPlannedMinutes

        // Set mode
        project.mode = pending.isPhaseMode ? .phase : .milestone

        // Set archetype (only for phase mode)
        if let archetypeStr = pending.archetype?.lowercased() {
            switch archetypeStr {
            case "lab": project.archetype = .lab
            case "hunt": project.archetype = .hunt
            case "spiral": project.archetype = .spiral
            case "build": project.archetype = .build
            default: break
            }
        }

        // Set deadline
        if let deadlineStr = pending.deadline {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            project.deadline = formatter.date(from: deadlineStr)
        }

        modelContext.insert(project)

        // Create phases (for phase mode)
        if pending.isPhaseMode {
            for (phaseIndex, pendingPhase) in pending.phases.enumerated() {
                let phase = ProjectPhase(
                    title: pendingPhase.title,
                    phaseType: parsePhaseType(pendingPhase.phaseType),
                    sequenceOrder: phaseIndex
                )
                phase.mentalRule = pendingPhase.mentalRule
                phase.estimatedMinutes = pendingPhase.estimatedMinutes
                phase.project = project

                modelContext.insert(phase)
            }
        }

        // Create milestones (for milestone mode)
        if pending.isMilestoneMode {
            for (milestoneIndex, pendingMilestone) in pending.milestones.enumerated() {
                let milestone = Milestone(
                    title: pendingMilestone.title,
                    sequenceOrder: milestoneIndex
                )
                milestone.descriptionText = pendingMilestone.description
                milestone.project = project

                modelContext.insert(milestone)
            }
        }

        try? modelContext.save()
    }

    /// Create a TouchLog from pending data
    private func createTouchLog(from pending: AgentService.PendingTouchLog) async {
        // Find the project if ID is provided
        var targetProject: Project?
        if let projectId = pending.projectId, let uuid = UUID(uuidString: projectId) {
            targetProject = activeProjects.first { $0.id == uuid }
        } else if let title = pending.projectTitle {
            // Match by title
            targetProject = activeProjects.first { $0.title.lowercased().contains(title.lowercased()) }
        }

        let log = TouchLog(durationMinutes: pending.durationMinutes)
        log.note = pending.note
        log.project = targetProject

        modelContext.insert(log)
        try? modelContext.save()
    }

    /// Parse phase type string to enum
    private func parsePhaseType(_ typeStr: String) -> PhaseType {
        switch typeStr.lowercased() {
        case "divergent": return .divergent
        case "convergent": return .convergent
        case "execution": return .execution
        case "input": return .input
        case "output": return .output
        case "reflection": return .reflection
        default: return .execution
        }
    }

    private func startNewSession() {
        agentService.startNewSession()
        messages = []
        briefing = nil
        pendingActions = []
        confirmedActionsClearTask?.cancel()
        confirmedActions = []
        suggestions = []
        conversationState = .initial

        Task {
            await checkBackendAndLoadBriefing()
        }
    }
}

// MARK: - Chat Message Model

struct AgentChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()

    enum Role {
        case user
        case assistant
    }
}

// MARK: - Message Bubble

struct AgentMessageBubble: View {
    let message: AgentChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(displayContent)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(message.role == .user ? .white : DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .fill(message.role == .user ? DesignSystem.Colors.accent : DesignSystem.Colors.cardBackground)
                    )

                Text(timeString)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    /// Strips JSON code blocks from assistant messages for cleaner display
    private var displayContent: String {
        guard message.role == .assistant else {
            return message.content
        }

        // Remove ```json ... ``` blocks from the content
        let pattern = "```json\\s*\\{[^`]*\\}\\s*```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return message.content
        }

        let range = NSRange(message.content.startIndex..., in: message.content)
        let cleaned = regex.stringByReplacingMatches(in: message.content, options: [], range: range, withTemplate: "")

        // Clean up extra whitespace/newlines left behind
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}

// MARK: - Briefing Card

struct BriefingCard: View {
    let briefing: AgentService.DailyBriefing

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(briefing.greeting)
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            if let suggestedFocus = briefing.suggestedFocus {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Label("Suggested Focus", systemImage: "lightbulb")
                        .font(DesignSystem.Typography.captionBold)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text(suggestedFocus)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
            }

            if let nudge = briefing.nudge {
                Text(nudge)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .italic()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let text: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(DesignSystem.Colors.accent)

                Text(text)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Compact suggestion chip for horizontal scroll in connected state
struct CompactSuggestionChip: View {
    let text: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Colors.accent)

                Text(text)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                Capsule()
                    .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Speech Input Sheet

struct SpeechInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var speechRecognizer = SpeechRecognizer()

    let onTranscribe: (String) -> Void

    private var isRecording: Bool {
        speechRecognizer.state == .recording
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Listening indicator - tappable to stop recording
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.accent.opacity(isRecording ? 0.3 : 0.1))
                        .frame(width: 150, height: 150)
                        .scaleEffect(isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(isRecording ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                }
                .contentShape(Circle())
                .onTapGesture {
                    if isRecording {
                        speechRecognizer.stopRecording()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if !speechRecognizer.transcript.isEmpty {
                                onTranscribe(speechRecognizer.transcript)
                                dismiss()
                            }
                        }
                    } else {
                        try? speechRecognizer.startRecording()
                    }
                }

                // Transcribed text
                if !speechRecognizer.transcript.isEmpty {
                    Text(speechRecognizer.transcript)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    Text(isRecording ? "Tap to stop" : "Tap to start")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                // Control buttons
                HStack(spacing: DesignSystem.Spacing.xl) {
                    Button {
                        speechRecognizer.reset()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(width: 100, height: 44)
                    }

                    Button {
                        if isRecording {
                            speechRecognizer.stopRecording()
                            // Wait briefly for processing, then return transcript
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if !speechRecognizer.transcript.isEmpty {
                                    onTranscribe(speechRecognizer.transcript)
                                    dismiss()
                                }
                            }
                        } else {
                            try? speechRecognizer.startRecording()
                        }
                    } label: {
                        Text(isRecording ? "Done" : "Start")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(.white)
                            .frame(width: 100, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .fill(DesignSystem.Colors.accent)
                            )
                    }
                }
            }
            .padding()
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Request authorization on appear
                _ = await speechRecognizer.requestAuthorization()
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    UnifiedInputView()
        .modelContainer(for: [Project.self, StoneEvent.self, TouchLog.self], inMemory: true)
}
