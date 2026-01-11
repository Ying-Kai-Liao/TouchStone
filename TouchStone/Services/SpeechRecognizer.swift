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
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var transcript: String = ""
    private(set) var isAvailable: Bool = false

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

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
            state = .error("Speech recognition not authorized")
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
            state = .error("Microphone access not authorized")
            return false
        }

        state = .idle
        return true
    }

    // MARK: - Recording

    func startRecording() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw RecognizerError.notAvailable
        }

        // Cancel any existing task
        stopRecording()

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
                self.transcript = result.bestTranscription.formattedString
            }

            if error != nil || (result?.isFinal ?? false) {
                self.cleanupAudio()
                if self.state == .recording {
                    self.state = .processing
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
    }

    func stopRecording() {
        recognitionRequest?.endAudio()
        cleanupAudio()

        if state == .recording {
            state = .processing
        }
    }

    private func cleanupAudio() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func reset() {
        stopRecording()
        transcript = ""
        state = .idle
    }

    func setIdle() {
        state = .idle
    }
}
