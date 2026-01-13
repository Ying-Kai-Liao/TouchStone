import SwiftUI
import SwiftData

struct SpeechStoneInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let initialDate: Date?

    @State private var speechRecognizer = SpeechRecognizer()
    @State private var parsedStone: SpeechParser.ParsedStone?
    @State private var showManualForm = false

    // Editable fields from parsed result
    @State private var title: String = ""
    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 10
    @State private var endMinute: Int = 0
    @State private var recurrence: RecurrenceType = .none

    init(initialDate: Date? = nil) {
        self.initialDate = initialDate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Microphone button
                microphoneSection

                // Transcript display
                transcriptSection

                // Parsed result preview
                if parsedStone?.isValid == true {
                    parsedPreviewSection
                }

                Spacer()

                // Action buttons
                actionButtons
            }
            .padding()
            .navigationTitle("Add Stone by Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        speechRecognizer.reset()
                        dismiss()
                    }
                }
            }
            .task {
                await speechRecognizer.requestAuthorization()
            }
            .sheet(isPresented: $showManualForm) {
                StoneEventFormView(onSave: { stone in
                    modelContext.insert(stone)
                    dismiss()
                }, initialDate: initialDate)
            }
        }
    }

    // MARK: - Microphone Section

    private var microphoneSection: some View {
        VStack(spacing: 16) {
            Button {
                toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(micButtonColor)
                        .frame(width: 100, height: 100)

                    if case .recording = speechRecognizer.state {
                        // Pulsing animation
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 4)
                            .frame(width: 100, height: 100)
                            .scaleEffect(1.2)
                            .opacity(0.5)
                            .animation(.easeInOut(duration: 1).repeatForever(), value: speechRecognizer.state)
                    }

                    Image(systemName: micIconName)
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }
            .disabled(!canRecord)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var micButtonColor: Color {
        switch speechRecognizer.state {
        case .recording: return .red
        case .processing: return .orange
        case .error: return .gray
        default: return .blue
        }
    }

    private var micIconName: String {
        switch speechRecognizer.state {
        case .recording: return "stop.fill"
        case .processing: return "ellipsis"
        default: return "mic.fill"
        }
    }

    private var statusText: String {
        switch speechRecognizer.state {
        case .idle: return "Tap to speak"
        case .requesting: return "Requesting permission..."
        case .recording: return "Listening... Tap to stop"
        case .processing: return "Processing..."
        case .error(let message): return message
        }
    }

    private var canRecord: Bool {
        switch speechRecognizer.state {
        case .idle, .recording: return true
        default: return false
        }
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        VStack(spacing: 8) {
            if !speechRecognizer.transcript.isEmpty {
                Text(speechRecognizer.transcript)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if case .idle = speechRecognizer.state {
                Text("Say something like:\n\"Team meeting at 10 AM\"\n\"Lunch from 12 to 1 daily\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Parsed Preview Section

    @ViewBuilder
    private var parsedPreviewSection: some View {
        if let parsed = parsedStone, parsed.isValid {
            VStack(alignment: .leading, spacing: 12) {
                Text("Parsed Event")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(title.isEmpty ? parsed.title : title)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text(timeRangeString)
                    }

                    if recurrence != .none {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundStyle(.secondary)
                            Text(recurrenceLabel)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var timeRangeString: String {
        let startStr = formatTime(hour: startHour, minute: startMinute)
        let endStr = formatTime(hour: endHour, minute: endMinute)
        return "\(startStr) - \(endStr)"
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let period = hour >= 12 ? "PM" : "AM"
        if minute == 0 {
            return "\(displayHour) \(period)"
        }
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    private var recurrenceLabel: String {
        switch recurrence {
        case .none: return "One time"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .weekly: return "Weekly"
        case .custom: return "Custom"
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if parsedStone?.isValid == true {
                Button {
                    saveStone()
                } label: {
                    Text("Add Stone")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button {
                showManualForm = true
            } label: {
                Text("Enter Manually")
                    .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        switch speechRecognizer.state {
        case .recording:
            speechRecognizer.stopRecording()
            // Parse after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                parseTranscript()
            }
        case .idle:
            do {
                try speechRecognizer.startRecording()
            } catch {
                print("Failed to start recording: \(error)")
            }
        default:
            break
        }
    }

    private func parseTranscript() {
        guard !speechRecognizer.transcript.isEmpty else { return }

        let parsed = SpeechParser.parse(speechRecognizer.transcript)
        parsedStone = parsed

        // Update editable fields
        title = parsed.title
        startHour = parsed.startHour ?? 9
        startMinute = parsed.startMinute
        endHour = parsed.endHour ?? (startHour + 1)
        endMinute = parsed.endMinute
        recurrence = parsed.recurrence

        speechRecognizer.setIdle()
    }

    private func saveStone() {
        let stone = StoneEvent(
            title: title,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            specificDate: recurrence == .none ? (initialDate ?? Date()) : nil,
            recurrence: RecurrencePattern(type: recurrence)
        )

        modelContext.insert(stone)
        speechRecognizer.reset()
        dismiss()
    }
}

#Preview {
    SpeechStoneInputView(initialDate: nil)
        .modelContainer(for: StoneEvent.self, inMemory: true)
}
