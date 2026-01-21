import SwiftUI
import SwiftData

/// Chat message types for the planning conversation
enum PlanningChatMessage: Identifiable {
    case assistantText(id: UUID = UUID(), text: String)
    case userText(id: UUID = UUID(), text: String)
    case assistantLoading(id: UUID = UUID(), text: String)
    case phaseAllocation(id: UUID = UUID())
    case sessionReview(id: UUID = UUID())

    var id: UUID {
        switch self {
        case .assistantText(let id, _): return id
        case .userText(let id, _): return id
        case .assistantLoading(let id, _): return id
        case .phaseAllocation(let id): return id
        case .sessionReview(let id): return id
        }
    }
}

/// Chat-based strategic planning flow
struct StrategicPlanningChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var prefs: UserPreferences { UserPreferences.shared }

    // Chat state
    @State private var messages: [PlanningChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var currentPhase: ChatPhase = .goalInput
    @SwiftUI.FocusState private var isInputFocused: Bool

    // Speech recognition
    @State private var speechRecognizer = SpeechRecognizer()

    // Planning state
    @State private var goal = ""
    @State private var projectTitle = ""
    @State private var archetype: Archetype?
    @State private var reasoning = ""
    @State private var phasePercents: [Int] = []
    @State private var totalHours: Int = 40
    @State private var generatedSessions: StrategyChatEngine.SessionsResult?
    @State private var errorMessage: String?

    private let engine = StrategyChatEngine()

    init() {}

    enum ChatPhase {
        case goalInput
        case classifying
        case phaseReview
        case generatingSessions
        case sessionReview
        case done
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            ForEach(messages) { message in
                                chatMessageView(message)
                                    .id(message.id)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.xl)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                inputBar
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Plan Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .onAppear {
                // Start with welcome message
                messages.append(.assistantText(
                    text: "What do you want to accomplish? Tell me about your project and I'll help you break it down into phases and sessions."
                ))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isInputFocused = true
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Chat Message View

    @ViewBuilder
    private func chatMessageView(_ message: PlanningChatMessage) -> some View {
        switch message {
        case .assistantText(_, let text):
            assistantBubble(text)

        case .userText(_, let text):
            userBubble(text)

        case .assistantLoading(_, let text):
            loadingBubble(text)

        case .phaseAllocation:
            phaseAllocationCard

        case .sessionReview:
            sessionReviewCard
        }
    }

    private func assistantBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            // AI avatar
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 28, height: 28)
                .background(DesignSystem.Colors.accent.opacity(0.15))
                .clipShape(Circle())

            Text(try! AttributedString(markdown: text))
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
                )

            Spacer(minLength: 44)
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 60)

            Text(text)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }

    private func loadingBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            // AI avatar
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 28, height: 28)
                .background(DesignSystem.Colors.accent.opacity(0.15))
                .clipShape(Circle())

            HStack(spacing: DesignSystem.Spacing.sm) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(DesignSystem.Colors.accent)
                Text(text)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
            )

            Spacer(minLength: 44)
        }
    }

    // MARK: - Phase Allocation Card

    private var phaseAllocationCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Archetype badge
            if let arch = archetype {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: arch.icon)
                        .foregroundStyle(DesignSystem.Colors.accent)
                    Text(arch.displayName)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
                .font(DesignSystem.Typography.callout)
            }

            // Title field
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Project Title")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                TextField("Project title", text: $projectTitle)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
            }

            // Total time
            TotalTimeControl(totalHours: $totalHours)

            // Phase cards
            if let arch = archetype {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(arch.phaseStructure.enumerated()), id: \.offset) { index, template in
                        PhaseAllocationCard(
                            phaseName: template.name,
                            phaseType: template.type,
                            mentalRule: template.rule,
                            index: index,
                            percent: binding(for: index),
                            totalMinutes: totalHours * 60,
                            onAdjust: { delta in adjustPhasePercent(index: index, delta: delta) }
                        )
                    }
                }
            }

            // Continue button
            Button {
                generateSessions()
            } label: {
                HStack {
                    Text("Generate Sessions")
                    Image(systemName: "sparkles")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.md)
                .background(projectTitle.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent)
                .foregroundStyle(DesignSystem.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
            }
            .disabled(projectTitle.isEmpty || isProcessing)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Session Review Card

    private var sessionReviewCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Project summary
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(projectTitle)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                if let arch = archetype {
                    Text(arch.displayName)
                        .font(DesignSystem.Typography.caption)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.accent.opacity(0.15))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .clipShape(Capsule())
                }

                Spacer()

                Text("\(totalHours)h")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            // Sessions list
            if let sessions = generatedSessions, let arch = archetype {
                SessionGoalsList(
                    phases: sessions.phases,
                    phaseStructure: arch.phaseStructure
                )
            }

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    // Go back to phase allocation
                    currentPhase = .phaseReview
                    // Remove session review from messages
                    messages.removeAll { msg in
                        if case .sessionReview = msg { return true }
                        return false
                    }
                    // Remove last assistant message about sessions
                    if let lastIndex = messages.lastIndex(where: { msg in
                        if case .assistantText(_, let text) = msg {
                            return text.contains("session")
                        }
                        return false
                    }) {
                        messages.remove(at: lastIndex)
                    }
                } label: {
                    Text("Adjust")
                        .font(DesignSystem.Typography.callout)
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.background)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                }

                Button {
                    createProject()
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Create Project")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.accent)
                    .foregroundStyle(DesignSystem.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(DesignSystem.Colors.divider)

            HStack(spacing: DesignSystem.Spacing.md) {
                // Microphone button
                Button {
                    toggleRecording()
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(isRecording ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary)
                        .symbolEffect(.pulse, isActive: isRecording)
                }
                .disabled(isProcessing)

                // Text field or recording indicator
                if isRecording {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Circle()
                            .fill(DesignSystem.Colors.error)
                            .frame(width: 8, height: 8)
                        Text(speechRecognizer.transcript.isEmpty ? "Listening..." : speechRecognizer.transcript)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField(inputPlaceholder, text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1...4)
                        .focused($isInputFocused)
                        .onSubmit {
                            sendMessage()
                        }
                }

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(canSend ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
        }
        .onChange(of: speechRecognizer.state) { _, newState in
            if newState == .finished {
                // Transfer transcript to input text
                let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !transcript.isEmpty {
                    inputText = transcript
                }
                speechRecognizer.reset()
            }
        }
    }

    private var isRecording: Bool {
        speechRecognizer.state == .recording || speechRecognizer.state == .processing
    }

    private var inputPlaceholder: String {
        switch currentPhase {
        case .goalInput:
            return "Describe your project goal..."
        case .phaseReview, .sessionReview:
            return "Type to adjust or ask questions..."
        default:
            return "Type a message..."
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    // MARK: - Actions

    private func toggleRecording() {
        if isRecording {
            speechRecognizer.stopRecording()
        } else {
            Task {
                let authorized = await speechRecognizer.requestAuthorization()
                if authorized {
                    do {
                        try speechRecognizer.startRecording()
                    } catch {
                        errorMessage = "Could not start recording: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""

        switch currentPhase {
        case .goalInput:
            // User entered their goal
            goal = text
            messages.append(.userText(text: text))
            classifyGoal()

        case .phaseReview, .sessionReview:
            // User feedback - for now just acknowledge
            messages.append(.userText(text: text))
            messages.append(.assistantText(
                text: "I understand. You can adjust the settings above, or tap \"Generate Sessions\" when you're ready."
            ))

        default:
            break
        }
    }

    private func classifyGoal() {
        isProcessing = true
        currentPhase = .classifying

        // Add loading message
        let loadingId = UUID()
        messages.append(.assistantLoading(id: loadingId, text: "Analyzing your goal..."))

        Task {
            do {
                let result = try await engine.classifyGoal(goal)
                await MainActor.run {
                    // Remove loading message
                    messages.removeAll { $0.id == loadingId }

                    if let arch = Archetype(rawValue: result.archetype.lowercased()) {
                        archetype = arch
                        reasoning = result.reasoning
                        projectTitle = result.suggestedTitle
                        phasePercents = arch.phaseStructure.map { $0.defaultPercent }
                        currentPhase = .phaseReview

                        // Add explanation message
                        messages.append(.assistantText(
                            text: "I identified this as a **\(arch.displayName)** project. \(reasoning)\n\nHere's a suggested plan structure. You can adjust the title, total time, and phase allocations:"
                        ))

                        // Add phase allocation card
                        messages.append(.phaseAllocation())
                    } else {
                        errorMessage = "Could not determine project type. Please try again."
                        currentPhase = .goalInput
                    }
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    messages.removeAll { $0.id == loadingId }
                    messages.append(.assistantText(
                        text: "Sorry, I encountered an error: \(error.localizedDescription). Please try again."
                    ))
                    currentPhase = .goalInput
                    isProcessing = false
                }
            }
        }
    }

    private func generateSessions() {
        guard let arch = archetype else { return }

        isProcessing = true
        currentPhase = .generatingSessions

        // Add loading message
        let loadingId = UUID()
        messages.append(.assistantLoading(id: loadingId, text: "Generating session goals..."))

        var allocation = StrategyChatEngine.PhaseAllocation(
            archetype: arch,
            totalMinutes: totalHours * 60
        )
        allocation.phasePercents = phasePercents

        Task {
            do {
                let result = try await engine.generateSessions(
                    title: projectTitle,
                    goal: goal,
                    allocation: allocation
                )
                await MainActor.run {
                    // Remove loading message
                    messages.removeAll { $0.id == loadingId }

                    generatedSessions = result
                    currentPhase = .sessionReview

                    // Add explanation
                    messages.append(.assistantText(
                        text: "Here are the sessions I've planned for your project. Review them and create your project when ready:"
                    ))

                    // Add session review card
                    messages.append(.sessionReview())

                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    messages.removeAll { $0.id == loadingId }
                    messages.append(.assistantText(
                        text: "Sorry, I encountered an error generating sessions: \(error.localizedDescription)"
                    ))
                    currentPhase = .phaseReview
                    isProcessing = false
                }
            }
        }
    }

    private func createProject() {
        guard let arch = archetype,
              let sessions = generatedSessions else { return }

        var allocation = StrategyChatEngine.PhaseAllocation(
            archetype: arch,
            totalMinutes: totalHours * 60
        )
        allocation.phasePercents = phasePercents

        Task {
            let (project, phases) = await engine.createProject(
                title: projectTitle,
                archetype: arch,
                allocation: allocation,
                sessionsResult: sessions
            )

            await MainActor.run {
                modelContext.insert(project)
                for phase in phases {
                    modelContext.insert(phase)
                    for session in phase.sessions {
                        modelContext.insert(session)
                    }
                }
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func binding(for index: Int) -> Binding<Int> {
        Binding(
            get: { index < phasePercents.count ? phasePercents[index] : 0 },
            set: { phasePercents[index] = $0 }
        )
    }

    private func adjustPhasePercent(index: Int, delta: Int) {
        guard index >= 0 && index < phasePercents.count else { return }

        let oldPercent = phasePercents[index]
        let newPercent = max(5, min(80, oldPercent + delta))

        if newPercent != oldPercent {
            phasePercents[index] = newPercent
            let actualDelta = newPercent - oldPercent
            redistributePercents(excludingIndex: index, delta: -actualDelta)
        }
    }

    private func redistributePercents(excludingIndex: Int, delta: Int) {
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

        let total = phasePercents.reduce(0, +)
        if total != 100 {
            let diff = 100 - total
            if let maxIdx = phasePercents.indices.max(by: { phasePercents[$0] < phasePercents[$1] }) {
                phasePercents[maxIdx] += diff
            }
        }
    }
}

#Preview {
    StrategicPlanningChatView()
        .modelContainer(for: [Project.self, ProjectPhase.self, PlannedSession.self], inMemory: true)
}
