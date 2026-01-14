import Foundation
import SwiftData

// MARK: - Backlog Model

/// Represents daily productive capacity as 1-hour blocks.
/// The scheduling algorithm draws from this pool when generating sessions.
/// Prevents over-scheduling and allows capacity adjustment per day.
@Model
final class Backlog {
    var id: UUID = UUID()
    var date: Date                    // Which day this capacity belongs to
    var totalHours: Int = 6           // Default 6 hours of productive capacity
    var allocatedHours: Int = 0       // Hours already scheduled
    var createdAt: Date = Date()

    // Relationship to day plan
    var dayPlan: DayPlan?

    // MARK: - Computed Properties

    /// Hours remaining in the capacity pool
    var remainingHours: Int {
        max(0, totalHours - allocatedHours)
    }

    /// Returns array of available 1-hour block indices
    /// e.g., [0, 1, 2, 3, 4, 5] for 6 hours capacity
    var hourBlocks: [Int] {
        Array(0..<remainingHours)
    }

    /// Whether there's any capacity left
    var hasCapacity: Bool {
        remainingHours > 0
    }

    /// Percentage of capacity used (0.0 - 1.0)
    var usagePercentage: Double {
        guard totalHours > 0 else { return 0 }
        return Double(allocatedHours) / Double(totalHours)
    }

    // MARK: - Initialization

    init(date: Date, totalHours: Int = 6) {
        self.date = Calendar.current.startOfDay(for: date)
        self.totalHours = totalHours
    }

    // MARK: - Methods

    /// Allocate hours from the capacity pool
    /// Returns the number of hours actually allocated (may be less if insufficient capacity)
    @discardableResult
    func allocate(hours: Int) -> Int {
        let available = remainingHours
        let toAllocate = min(hours, available)
        allocatedHours += toAllocate
        return toAllocate
    }

    /// Release previously allocated hours back to the pool
    func release(hours: Int) {
        allocatedHours = max(0, allocatedHours - hours)
    }

    /// Reset allocation (e.g., when regenerating schedule)
    func resetAllocation() {
        allocatedHours = 0
    }
}
