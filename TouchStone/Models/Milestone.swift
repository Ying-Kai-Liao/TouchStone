import Foundation
import SwiftData

// MARK: - Milestone Model

/// A Milestone represents a checkable deliverable within a milestone-mode project.
/// Milestones are simple binary items: done or not done.
/// User can check them off as they complete each deliverable.
@Model
final class Milestone {
    var id: UUID
    var title: String
    var descriptionText: String?  // Using descriptionText to avoid conflict with Swift's description
    var isCompleted: Bool
    var completedAt: Date?
    var sequenceOrder: Int
    var createdAt: Date

    var project: Project?

    init(
        id: UUID = UUID(),
        title: String,
        descriptionText: String? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        sequenceOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.sequenceOrder = sequenceOrder
        self.createdAt = createdAt
    }

    // MARK: - Actions

    func toggleCompletion() {
        if isCompleted {
            isCompleted = false
            completedAt = nil
        } else {
            isCompleted = true
            completedAt = Date()
        }
    }

    func markComplete() {
        isCompleted = true
        completedAt = Date()
    }

    func markIncomplete() {
        isCompleted = false
        completedAt = nil
    }
}
