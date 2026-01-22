import SwiftUI
import SwiftData

/// Chat message types for the stone creation conversation
enum StoneChatMessage: Identifiable {
    case assistantText(id: UUID = UUID(), text: String)
    case userText(id: UUID = UUID(), text: String)
    case assistantLoading(id: UUID = UUID(), text: String)
    case stonePreview(id: UUID = UUID())

    var id: UUID {
        switch self {
        case .assistantText(let id, _): return id
        case .userText(let id, _): return id
        case .assistantLoading(let id, _): return id
        case .stonePreview(let id): return id
        }
    }
}

/// Chat-based stone event creation interface
struct StoneChatInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let initialDate: Date?

    // Chat state
    @State private var messages: [StoneChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @SwiftUI.FocusState private var isInputFocused: Bool

    // Speech recognition
    @State private var speechRecognizer = SpeechRecognizer()

    // Parsed result state
    @State private var parsedStone: StoneParserService.ParsedStoneEvent?
    @State private var errorMessage: String?

    // Editable fields
    @State private var title = ""
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var endHour = 10
    @State private var endMinute = 0
    @State private var recurrence: RecurrenceType = .none
    @State private var customDays: Set<Int> = []
    @State private var specificDate = Date()

    private let parserService = StoneParserService()

    init(initialDate: Date? = nil) {
        self.initialDate = initialDate
        _specificDate = State(initialValue: initialDate ?? Date())
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
            .navigationTitle("Add Stone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .onAppear {
                messages.append(.assistantText(
                    text: "Tell me about your event. For example:\n• \"Team meeting at 10 AM\"\n• \"Lunch from 12 to 1 daily\"\n• \"Gym at 6 PM on weekdays\""
                ))
                // Auto-start microphone recording
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startRecordingAutomatically()
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
    private func chatMessageView(_ message: StoneChatMessage) -> some View {
        switch message {
        case .assistantText(_, let text):
            assistantBubble(text)

        case .userText(_, let text):
            userBubble(text)

        case .assistantLoading(_, let text):
            loadingBubble(text)

        case .stonePreview:
            stonePreviewCard
        }
    }

    private func assistantBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            // AI avatar
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 28, height: 28)
                .background(DesignSystem.Colors.accent.opacity(0.15))
                .clipShape(Circle())

            Text(text)
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
            Image(systemName: "clock.badge.checkmark")
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

    // MARK: - Stone Preview Card

    private var stonePreviewCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 0.5))
                Text("EVENT READY")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .tracking(1.5)
            }

            // Event title
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("EVENT NAME")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1)
                TextField("Event name", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }

            Divider()
                .background(DesignSystem.Colors.textTertiary.opacity(0.2))

            // Time section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .tracking(1)
                    Text(timeRangeString)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                Spacer()

                // Time adjustment buttons
                Menu {
                    ForEach(0..<24, id: \.self) { hour in
                        Button(formatHour(hour)) {
                            startHour = hour
                            if endHour <= startHour {
                                endHour = (startHour + 1) % 24
                            }
                        }
                    }
                } label: {
                    Text("Start")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.accent.opacity(0.15))
                        .clipShape(Capsule())
                }

                Menu {
                    ForEach(0..<24, id: \.self) { hour in
                        Button(formatHour(hour)) {
                            endHour = hour
                        }
                    }
                } label: {
                    Text("End")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // Recurrence section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("REPEATS")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    recurrenceChip("Once", type: .none)
                    recurrenceChip("Daily", type: .daily)
                    recurrenceChip("Weekdays", type: .weekdays)
                    recurrenceChip("Weekends", type: .weekends)
                }

                if recurrence == .none {
                    DatePicker("Date", selection: $specificDate, displayedComponents: .date)
                        .font(DesignSystem.Typography.body)
                }

                if recurrence == .custom {
                    customDaysSelector
                }
            }

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    // Reset to allow new input
                    parsedStone = nil
                    messages.removeAll { msg in
                        if case .stonePreview = msg { return true }
                        return false
                    }
                    messages.append(.assistantText(text: "No problem! Tell me about a different event."))
                } label: {
                    Text("Try Again")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.background)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                }

                Button {
                    saveStone()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Add Stone")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(title.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
                    .foregroundStyle(DesignSystem.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                }
                .disabled(title.isEmpty)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.15), lineWidth: 1)
        )
    }

    private func recurrenceChip(_ label: String, type: RecurrenceType) -> some View {
        Button {
            recurrence = type
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(recurrence == type ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.background)
                .foregroundStyle(recurrence == type ? DesignSystem.Colors.background : DesignSystem.Colors.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: recurrence == type ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var customDaysSelector: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach([(1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")], id: \.0) { day, label in
                Button {
                    if customDays.contains(day) {
                        customDays.remove(day)
                    } else {
                        customDays.insert(day)
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(customDays.contains(day) ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.background)
                        .foregroundStyle(customDays.contains(day) ? DesignSystem.Colors.background : DesignSystem.Colors.textSecondary)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: customDays.contains(day) ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
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
                    TextField("Describe your event...", text: $inputText, axis: .vertical)
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
                let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !transcript.isEmpty {
                    inputText = transcript
                    // Auto-send after voice input
                    sendMessage()
                }
                speechRecognizer.reset()
            }
        }
    }

    private var isRecording: Bool {
        speechRecognizer.state == .recording || speechRecognizer.state == .processing
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing && parsedStone == nil
    }

    // MARK: - Helpers

    private var timeRangeString: String {
        let startStr = formatHour(startHour)
        let endStr = formatHour(endHour)
        return "\(startStr) - \(endStr)"
    }

    private func formatHour(_ hour: Int) -> String {
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let period = hour >= 12 ? "PM" : "AM"
        return "\(displayHour) \(period)"
    }

    // MARK: - Actions

    private func startRecordingAutomatically() {
        Task {
            let authorized = await speechRecognizer.requestAuthorization()
            if authorized {
                do {
                    try speechRecognizer.startRecording()
                } catch {
                    // Silently fall back to text input if mic fails
                    await MainActor.run {
                        isInputFocused = true
                    }
                }
            } else {
                // If not authorized, fall back to text input
                await MainActor.run {
                    isInputFocused = true
                }
            }
        }
    }

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
        messages.append(.userText(text: text))
        parseInput(text)
    }

    private func parseInput(_ text: String) {
        isProcessing = true

        let loadingId = UUID()
        messages.append(.assistantLoading(id: loadingId, text: "Understanding your event..."))

        Task {
            do {
                let result = try await parserService.parse(text)
                await MainActor.run {
                    messages.removeAll { $0.id == loadingId }

                    if result.isValid {
                        parsedStone = result

                        // Populate editable fields
                        title = result.title
                        startHour = result.startHour
                        startMinute = result.startMinute
                        endHour = result.endHour
                        endMinute = result.endMinute
                        recurrence = result.recurrence
                        if let days = result.customDays {
                            customDays = Set(days)
                        }
                        if let dateStr = result.specificDate {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            specificDate = formatter.date(from: dateStr) ?? (initialDate ?? Date())
                        }

                        messages.append(.assistantText(text: "I've parsed your event. Review the details below and make any adjustments:"))
                        messages.append(.stonePreview())
                    } else {
                        messages.append(.assistantText(
                            text: "I couldn't fully understand that. Could you try again with more details? For example: \"Meeting with team at 2 PM for 1 hour\""
                        ))
                    }
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    messages.removeAll { $0.id == loadingId }
                    messages.append(.assistantText(
                        text: "Sorry, I had trouble processing that: \(error.localizedDescription). Please try again or check your API key in Settings."
                    ))
                    isProcessing = false
                }
            }
        }
    }

    private func saveStone() {
        let recurrencePattern: RecurrencePattern
        switch recurrence {
        case .none:
            recurrencePattern = .none
        case .daily:
            recurrencePattern = .daily
        case .weekdays:
            recurrencePattern = .weekdays
        case .weekends:
            recurrencePattern = .weekends
        case .weekly:
            recurrencePattern = .weekly
        case .custom:
            recurrencePattern = .custom(days: Array(customDays))
        }

        let stone = StoneEvent(
            title: title,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            specificDate: (recurrence == .none || recurrence == .weekly) ? specificDate : nil,
            recurrence: recurrencePattern
        )

        modelContext.insert(stone)
        dismiss()
    }
}

#Preview {
    StoneChatInputView(initialDate: nil)
        .modelContainer(for: StoneEvent.self, inMemory: true)
}
