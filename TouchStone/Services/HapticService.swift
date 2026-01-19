import UIKit

/// Centralized haptic feedback service for consistent UX across the app
/// Provides different feedback styles for various interaction types
enum HapticService {

    // MARK: - Impact Feedback

    /// Light tap - for subtle interactions like card expansion, toggles
    static func lightTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium tap - for confirmations, primary actions
    static func mediumTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy tap - for significant actions like deletions
    static func heavyTap() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Soft tap - for very subtle feedback
    static func softTap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    /// Rigid tap - for more pronounced feedback
    static func rigidTap() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    // MARK: - Selection Feedback

    /// Selection change - for tab switches, picker changes
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Notification Feedback

    /// Success feedback - for completed actions
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning feedback - for alerts or cautions
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error feedback - for failed actions
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Semantic Helpers

    /// Feedback for touching/logging a project
    static func touch() {
        mediumTap()
    }

    /// Feedback for starting focus mode
    static func startFocus() {
        mediumTap()
    }

    /// Feedback for completing a session
    static func complete() {
        success()
    }

    /// Feedback for expanding/collapsing cards
    static func expand() {
        lightTap()
    }

    /// Feedback for button presses
    static func buttonPress() {
        lightTap()
    }

    /// Feedback for tab selection
    static func tabSelect() {
        selection()
    }

    /// Feedback for undo actions
    static func undo() {
        lightTap()
    }

    /// Feedback for delete actions
    static func delete() {
        lightTap()
    }

    /// Feedback for confirming daily work
    static func confirmDay() {
        success()
    }
}
