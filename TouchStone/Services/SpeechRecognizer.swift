import Foundation
import Speech
import AVFoundation

@Observable
class SpeechRecognizer {
    enum RecognizerError: Error {
        case notAuthorized
        case notAvailable
        case audioSessionError
        case recognitionError(String)
    }

    enum State: Equatable {
        case idle
        case requesting
        case recording
        case processing
        case finished  // New state: recognition complete, ready to parse
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var transcript: String = ""
    private(set) var isAvailable: Bool = false

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recordingTimer: Timer?
    private let maxRecordingDuration: TimeInterval = 30 // Auto-stop after 30 seconds

    init() {
        checkAvailability()
    }

    private func checkAvailability() {
        isAvailable = speechRecognizer?.isAvailable ?? false
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        state = .requesting

        // Request speech recognition authorization
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            await MainActor.run {
                state = .error("Speech recognition not authorized")
            }
            return false
        }

        // Request microphone authorization
        let micStatus: Bool
        if #available(iOS 17.0, *) {
            micStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            micStatus = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        guard micStatus else {
            await MainActor.run {
                state = .error("Microphone access not authorized")
            }
            return false
        }

        await MainActor.run {
            state = .idle
        }
        return true
    }

    // MARK: - Recording

    func startRecording() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw RecognizerError.notAvailable
        }

        // Cancel any existing task
        cleanupAudio()

        transcript = ""
        state = .recording

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw RecognizerError.audioSessionError
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw RecognizerError.audioSessionError
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }

                // If final result, mark as finished
                if result.isFinal {
                    DispatchQueue.main.async {
                        self.finishRecording()
                    }
                }
            }

            if let error = error {
                DispatchQueue.main.async {
                    // Only set error if we were still recording/processing
                    if self.state == .recording || self.state == .processing {
                        if self.transcript.isEmpty {
                            self.state = .error("Could not recognize speech")
                        } else {
                            // We have some transcript, finish successfully
                            self.finishRecording()
                        }
                    }
                }
            }
        }

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Start auto-stop timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
            self?.stopRecording()
        }
    }

    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        guard state == .recording else { return }

        state = .processing
        recognitionRequest?.endAudio()

        // Give recognition a moment to finalize, then force finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.state == .processing {
                self.finishRecording()
            }
        }
    }

    private func finishRecording() {
        cleanupAudio()
        state = .finished
    }

    private func cleanupAudio() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        cleanupAudio()
        transcript = ""
        state = .idle
    }

    func setIdle() {
        if state == .finished || state == .processing {
            state = .idle
        }
    }
}
