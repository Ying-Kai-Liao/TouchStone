import SwiftUI
import SwiftData

/// Sheet wrapper for the Ask flow when creating a new project
/// Provides a focused project creation experience using the AI assistant
struct ProjectAskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var agentService = AgentService.shared

    @Query(filter: #Predicate<Project> { $0.isActive }, sort: \Project.createdAt, order: .reverse)
    private var activeProjects: [Project]

    @Query private var allStones: [StoneEvent]

    @State private var inputText = ""
    @State private var messages: [AgentChatMessage] = []
    @State private var showingSpeechInput = false
    @State private var isBackendAvailable = false
    @State private var errorMessage: String?

    @State private var pendingActions: [AgentService.PendingAction] = []
    @State private var suggestions: [String] = []
    @State private var conversationState: AgentService.ConversationState = .initial

    // Confirmed actions (displayed after commit)
    @State private var confirmedActions: [AgentService.PendingAction] = []

    @SwiftUI.FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    messagesView
                    inputBar
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await checkBackend()
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
                    // Empty state with project-focused suggestions
                    if messages.isEmpty {
                        emptyStateView
                    }

                    // Chat messages
                    ForEach(messages) { message in
                        AgentMessageBubble(message: message)
                            .padding(.horizontal)
                            .id(message.id)
                    }

                    // Pending actions preview
                    if !pendingActions.isEmpty && (conversationState == .initial || conversationState == .refining) {
                        PendingActionsPreview(
                            pendingActions: pendingActions,
                            suggestions: suggestions,
                            onConfirm: { confirmPendingActions() },
                            onCancel: { cancelPendingActions() },
                            onSuggestionTap: { suggestion in sendMessage(suggestion) },
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
                }
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .onChange(of: messages.count) {
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("What would you like to work on?")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Describe your project and I'll help you plan it")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                SuggestionChip(text: "I want to write a book", icon: "book") {
                    sendMessage("I want to write a book")
                }
                SuggestionChip(text: "Build a side project", icon: "hammer") {
                    sendMessage("I want to build a side project")
                }
                SuggestionChip(text: "Learn a new skill", icon: "brain.head.profile") {
                    sendMessage("I want to learn a new skill")
                }
                SuggestionChip(text: "Prepare a presentation", icon: "person.and.background.dotted") {
                    sendMessage("I need to prepare a presentation")
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

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: DesignSystem.Spacing.md) {
                TextField("Describe your project...", text: $inputText, axis: .vertical)
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

    private func checkBackend() async {
        isBackendAvailable = await agentService.healthCheck()
    }

    private func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }

        let userMessage = AgentChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isInputFocused = false

        Task {
            do {
                let context = buildContext()
                let response = try await agentService.chat(message: text, context: context)

                let assistantMessage = AgentChatMessage(role: .assistant, content: response.message)
                messages.append(assistantMessage)

                pendingActions = response.pendingActions
                suggestions = response.suggestions
                conversationState = response.conversationState

                // Handle confirmed actions from backend (multi-task flow)
                if !response.confirmedActions.isEmpty {
                    // Commit to local storage
                    await commitActions(response.confirmedActions)

                    // Show confirmed preview
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        confirmedActions = response.confirmedActions
                    }

                    // Dismiss after showing confirmation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func buildContext() -> AgentService.UserContext {
        let stonesForToday = allStones.filter { $0.occursOn(date: Date()) }

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

                    // Show confirmed preview
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        confirmedActions = response.confirmedActions
                    }

                    // Dismiss after showing confirmation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
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

    private func cancelPendingActions() {
        pendingActions = []
        suggestions = []
        conversationState = .initial
        sendMessage("Cancel")
    }

    private func updateProjectTime(projectId: String, newMinutes: Int) {
        guard let index = pendingActions.firstIndex(where: { $0.project?.id == projectId }),
              let oldProject = pendingActions[index].project else {
            return
        }

        let oldTotal = max(oldProject.totalPlannedMinutes, 1)
        let scaleFactor = Double(newMinutes) / Double(oldTotal)

        let scaledPhases = oldProject.phases.map { phase in
            AgentService.PendingPhase(
                title: phase.title,
                phaseType: phase.phaseType,
                mentalRule: phase.mentalRule,
                estimatedMinutes: max(30, Int(Double(phase.estimatedMinutes) * scaleFactor))
            )
        }

        let scaledMilestones = oldProject.milestones.map { milestone in
            AgentService.PendingMilestone(
                title: milestone.title,
                description: milestone.description,
                sequenceOrder: milestone.sequenceOrder,
                estimatedMinutes: max(15, Int(Double(milestone.estimatedMinutes) * scaleFactor))
            )
        }

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

    /// Commit pending actions from state (legacy path)
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

        // Dismiss after a brief delay to show confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }

    /// Create SwiftData objects from a list of actions
    private func commitActions(_ actions: [AgentService.PendingAction]) async {
        for action in actions {
            switch action.actionType {
            case "add_project":
                if let project = action.project {
                    await createProject(from: project)
                }
            default:
                break
            }
        }
    }

    private func createProject(from pending: AgentService.PendingProject) async {
        let project = Project(title: pending.title)
        project.planningContext = pending.title
        project.totalPlannedMinutes = pending.totalPlannedMinutes

        project.mode = pending.isPhaseMode ? .phase : .milestone

        if let archetypeStr = pending.archetype?.lowercased() {
            switch archetypeStr {
            case "lab": project.archetype = .lab
            case "hunt": project.archetype = .hunt
            case "spiral": project.archetype = .spiral
            case "build": project.archetype = .build
            default: break
            }
        }

        if let deadlineStr = pending.deadline {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            project.deadline = formatter.date(from: deadlineStr)
        }

        modelContext.insert(project)

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
}

#Preview {
    ProjectAskSheet()
        .modelContainer(for: [Project.self, StoneEvent.self, ProjectPhase.self, Milestone.self], inMemory: true)
}
