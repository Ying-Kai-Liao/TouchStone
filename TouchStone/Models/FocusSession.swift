import Foundation
import SwiftData

// MARK: - Focus Session State

enum FocusState: String, Codable {
    case idle           // No active session
    case running        // Timer is running
    case paused         // Timer is paused
    case completed      // Session finished naturally
    case cancelled      // Session was cancelled
}

// MARK: - Focus Session Model

/// A FocusSession represents an active focus timer.
/// This is optional - users can log touches without timing.
/// When completed, it automatically creates a TouchLog.
@Model
final class FocusSession {
    var id: UUID
    var startTime: Date
    var targetMinutes: Int          // Target duration (default 55 min)
    var pausedAt: Date?             // When paused (if paused)
    var accumulatedPauseSeconds: Int // Total paused time
    var stateRaw: String            // FocusState raw value

    var project: Project?

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        targetMinutes: Int = 55,
        project: Project? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.targetMinutes = targetMinutes
        self.pausedAt = nil
        self.accumulatedPauseSeconds = 0
        self.stateRaw = FocusState.running.rawValue
        self.project = project
    }

    // MARK: - State Management

    var state: FocusState {
        get { FocusState(rawValue: stateRaw) ?? .idle }
        set { stateRaw = newValue.rawValue }
    }

    var isActive: Bool {
        state == .running || state == .paused
    }

    // MARK: - Time Calculations

    /// Elapsed time in seconds (excluding paused time)
    var elapsedSeconds: Int {
        guard state != .idle else { return 0 }

        let now = Date()
        let totalSeconds = Int(now.timeIntervalSince(startTime))
        let pauseSeconds = accumulatedPauseSeconds

        // If currently paused, don't count time since pause
        if let pausedAt = pausedAt {
            let currentPause = Int(now.timeIntervalSince(pausedAt))
            return totalSeconds - pauseSeconds - currentPause
        }

        return totalSeconds - pauseSeconds
    }

    /// Remaining time in seconds
    var remainingSeconds: Int {
        max(0, (targetMinutes * 60) - elapsedSeconds)
    }

    /// Progress as percentage (0.0 - 1.0)
    var progress: Double {
        let target = Double(targetMinutes * 60)
        guard target > 0 else { return 0 }
        return min(1.0, Double(elapsedSeconds) / target)
    }

    /// Formatted remaining time (MM:SS)
    var remainingTimeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Formatted elapsed time (MM:SS)
    var elapsedTimeString: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Actions

    func pause() {
        guard state == .running else { return }
        pausedAt = Date()
        state = .paused
    }

    func resume() {
        guard state == .paused, let pausedAt = pausedAt else { return }
        let pauseDuration = Int(Date().timeIntervalSince(pausedAt))
        accumulatedPauseSeconds += pauseDuration
        self.pausedAt = nil
        state = .running
    }

    func complete() {
        state = .completed
    }

    func cancel() {
        state = .cancelled
    }

    /// Create a TouchLog from this completed session
    func createTouchLog() -> TouchLog? {
        guard state == .completed || state == .cancelled else { return nil }

        // Round to nearest duration bucket
        let minutes = elapsedSeconds / 60
        let roundedMinutes: Int
        switch minutes {
        case ..<20: roundedMinutes = 15
        case 20..<40: roundedMinutes = 30
        case 40..<50: roundedMinutes = 45
        case 50..<70: roundedMinutes = 60
        case 70..<100: roundedMinutes = 90
        default: roundedMinutes = 120
        }

        return TouchLog(
            timestamp: startTime,
            durationMinutes: roundedMinutes,
            project: project
        )
    }
}
