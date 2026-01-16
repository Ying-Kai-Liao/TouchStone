import SwiftUI
import SwiftData

struct SpeechStoneInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let initialDate: Date?

    @State private var speechRecognizer = SpeechRecognizer()
    @State private var parsedStone: SpeechParser.ParsedStone?
    @State private var showManualForm = false
    @State private var showEditSheet = false

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
            .onChange(of: speechRecognizer.state) { oldValue, newValue in
                // Auto-parse when recognition finishes
                if newValue == .finished {
                    parseTranscript()
                }
            }
            .sheet(isPresented: $showManualForm) {
                StoneEventFormView(onSave: { stone in
                    modelContext.insert(stone)
                    dismiss()
                }, initialDate: initialDate)
            }
            .sheet(isPresented: $showEditSheet) {
                editParsedResultSheet
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
                            .frame(width: 120, height: 120)
                            .scaleEffect(pulseScale)
                            .opacity(0.6)
                    }

                    if case .processing = speechRecognizer.state {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    } else {
                        Image(systemName: micIconName)
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                    }
                }
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speechRecognizer.state)
            }
            .disabled(!canRecord)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @State private var pulseScale: CGFloat = 1.0

    private var micButtonColor: Color {
        switch speechRecognizer.state {
        case .recording: return .red
        case .processing: return .orange
        case .finished: return .green
        case .error: return .gray
        default: return UserPreferences.shared.accentColor
        }
    }

    private var micIconName: String {
        switch speechRecognizer.state {
        case .recording: return "stop.fill"
        case .finished: return "checkmark"
        default: return "mic.fill"
        }
    }

    private var statusText: String {
        switch speechRecognizer.state {
        case .idle: return "Tap to speak"
        case .requesting: return "Requesting permission..."
        case .recording: return "Listening... Tap to stop"
        case .processing: return "Processing speech..."
        case .finished: return parsedStone?.isValid == true ? "Ready to add!" : "Tap mic to try again"
        case .error(let message): return message
        }
    }

    private var canRecord: Bool {
        switch speechRecognizer.state {
        case .idle, .finished, .error: return true
        case .recording: return true
        default: return false
        }
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        VStack(spacing: 8) {
            if !speechRecognizer.transcript.isEmpty {
                VStack(spacing: 8) {
                    Text(speechRecognizer.transcript)
                        .font(.title3)
                        .multilineTextAlignment(.center)

                    if speechRecognizer.state == .finished && parsedStone?.isValid != true {
                        Text("Could not parse event. Try again or enter manually.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if case .idle = speechRecognizer.state {
                VStack(spacing: 8) {
                    Text("Try saying:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• \"Team meeting at 10 AM\"")
                        Text("• \"Lunch from 12 to 1 daily\"")
                        Text("• \"Gym at 6 PM on weekdays\"")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Parsed Preview Section

    @ViewBuilder
    private var parsedPreviewSection: some View {
        if let parsed = parsedStone, parsed.isValid {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Parsed Event")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Edit") {
                        showEditSheet = true
                    }
                    .font(.caption)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(title.isEmpty ? parsed.title : title)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(timeRangeString)
                    }

                    if recurrence != .none {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
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

    // MARK: - Edit Sheet

    private var editParsedResultSheet: some View {
        NavigationStack {
            Form {
                Section("Event Name") {
                    TextField("Title", text: $title)
                }

                Section("Time") {
                    HStack {
                        Text("Start")
                        Spacer()
                        Picker("Hour", selection: $startHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(formatTime(hour: h, minute: 0)).tag(h)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                        Picker("Minute", selection: $startMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in
                                Text(String(format: ":%02d", m)).tag(m)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("End")
                        Spacer()
                        Picker("Hour", selection: $endHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(formatTime(hour: h, minute: 0)).tag(h)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                        Picker("Minute", selection: $endMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in
                                Text(String(format: ":%02d", m)).tag(m)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                Section("Repeat") {
                    Picker("Recurrence", selection: $recurrence) {
                        Text("None").tag(RecurrenceType.none)
                        Text("Daily").tag(RecurrenceType.daily)
                        Text("Weekdays").tag(RecurrenceType.weekdays)
                        Text("Weekends").tag(RecurrenceType.weekends)
                        Text("Weekly").tag(RecurrenceType.weekly)
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showEditSheet = false
                    }
                }
            }
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
                        .background(UserPreferences.shared.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 16) {
                if speechRecognizer.state == .finished || speechRecognizer.state != .idle {
                    Button {
                        speechRecognizer.reset()
                        parsedStone = nil
                        title = ""
                    } label: {
                        Label("Start Over", systemImage: "arrow.counterclockwise")
                    }
                }

                Button {
                    showManualForm = true
                } label: {
                    Label("Enter Manually", systemImage: "keyboard")
                }
            }
            .font(.subheadline)
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        switch speechRecognizer.state {
        case .recording:
            speechRecognizer.stopRecording()
        case .idle, .finished, .error:
            // Reset if retrying
            if speechRecognizer.state != .idle {
                speechRecognizer.reset()
                parsedStone = nil
            }
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
        guard !speechRecognizer.transcript.isEmpty else {
            speechRecognizer.setIdle()
            return
        }

        let parsed = SpeechParser.parse(speechRecognizer.transcript)
        parsedStone = parsed

        // Update editable fields
        title = parsed.title
        startHour = parsed.startHour ?? 9
        startMinute = parsed.startMinute
        endHour = parsed.endHour ?? (startHour + 1)
        endMinute = parsed.endMinute
        recurrence = parsed.recurrence
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
