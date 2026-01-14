import SwiftUI

// MARK: - Flow Item Row

/// Displays a single item in the workflow timeline.
/// Handles stones, waters, breathing spaces, and flow prep with different visual styles.
struct FlowItemRow: View {
    let item: WorkflowItem
    let onTouch: (() -> Void)?
    let onFocus: (() -> Void)?

    var body: some View {
        switch item.type {
        case .stone:
            StoneFlowRow(item: item)
        case .water:
            WaterFlowRow(item: item, onTouch: onTouch, onFocus: onFocus)
        case .breathingSpace(let minutes):
            BreathingSpaceRow(minutes: minutes)
        case .flowPrep(let minutes):
            FlowPrepRow(minutes: minutes)
        }
    }
}

// MARK: - Stone Flow Row

/// Fixed event card with completion status
struct StoneFlowRow: View {
    let item: WorkflowItem

    private var statusIcon: String {
        switch item.status {
        case .completed:
            return "checkmark"
        case .inProgress:
            return "play.fill"
        case .upcoming:
            return "circle"
        case .overdue:
            return "arrow.counterclockwise"
        case .suggested:
            return "circle"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .completed:
            return .green
        case .inProgress:
            return .blue
        case .upcoming:
            return .secondary
        case .overdue:
            return .orange
        case .suggested:
            return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor)
            }

            // Stone details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(item.status == .completed ? .secondary : .primary)

                Text(item.timeRangeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Participant avatars placeholder (for future)
            if item.status == .inProgress {
                Text("IN FLOW")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .opacity(item.status == .completed ? 0.6 : 1)
        )
    }
}

// MARK: - Water Flow Row

/// Suggested session card with touch and focus actions.
/// Appears as ghost block (dashed, translucent) before touch, solid block after touch.
struct WaterFlowRow: View {
    let item: WorkflowItem
    let onTouch: (() -> Void)?
    let onFocus: (() -> Void)?

    /// Check if this project was touched today
    private var hasTouchedToday: Bool {
        guard let project = item.project else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return project.touchLogs.contains { log in
            calendar.startOfDay(for: log.timestamp) == today
        }
    }

    /// Ghost styling for untouched, solid for touched
    private var isGhost: Bool {
        !hasTouchedToday
    }

    var body: some View {
        // Whole block is tappable to touch
        Button(action: { onTouch?() }) {
            HStack(alignment: .center, spacing: 16) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(isGhost ? 0.1 : 0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: hasTouchedToday ? "checkmark" : "circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isGhost ? .teal.opacity(0.5) : .teal)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.primary.opacity(isGhost ? 0.6 : 1.0))

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.timeRangeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Focus button - small icon inside the block
                if let onFocus = onFocus {
                    Button(action: onFocus) {
                        Image(systemName: "scope")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.orange)
                            .frame(width: 36, height: 36)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground).opacity(isGhost ? 0.5 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isGhost ? Color.teal.opacity(0.3) : Color.clear,
                        style: StrokeStyle(lineWidth: 1, dash: isGhost ? [6, 4] : [])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Breathing Space Row

/// Small bubble for breathing space between activities
struct BreathingSpaceRow: View {
    let minutes: Int

    var body: some View {
        HStack {
            Spacer()
            Text("Breathing Space \u{00B7} \(minutes)m")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(.systemGray5))
                )
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Flow Prep Row

/// Small bubble for flow state preparation
struct FlowPrepRow: View {
    let minutes: Int

    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text("Flow State Prep \u{00B7} \(minutes)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.1))
            )
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Overdue Item Row

/// Row for items that are past due and not completed
struct OverdueItemRow: View {
    let item: WorkflowItem
    let onReschedule: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Repeat icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Yesterday \u{00B7} 1h estimate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let onReschedule = onReschedule {
                Button("Reschedule?", action: onReschedule)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Additional Project Row

/// A compact touch block for projects not in the scheduled flow.
/// Always appears as ghost until touched.
struct AdditionalProjectRow: View {
    let project: Project
    let onTouch: () -> Void
    let onFocus: () -> Void

    /// Check if this project was touched today
    private var hasTouchedToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return project.touchLogs.contains { log in
            calendar.startOfDay(for: log.timestamp) == today
        }
    }

    private var isGhost: Bool {
        !hasTouchedToday
    }

    var body: some View {
        // Whole block is tappable to touch
        Button(action: onTouch) {
            HStack(alignment: .center, spacing: 12) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(isGhost ? 0.1 : 0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: hasTouchedToday ? "checkmark" : "circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isGhost ? .teal.opacity(0.5) : .teal)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary.opacity(isGhost ? 0.6 : 1.0))

                    if let phase = project.currentPhase, !phase.isEmpty {
                        Text(phase)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Focus button - small icon inside the block
                Button(action: onFocus) {
                    Image(systemName: "scope")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                        .frame(width: 30, height: 30)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground).opacity(isGhost ? 0.5 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isGhost ? Color.teal.opacity(0.3) : Color.clear,
                        style: StrokeStyle(lineWidth: 1, dash: isGhost ? [6, 4] : [])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        BreathingSpaceRow(minutes: 30)
        FlowPrepRow(minutes: 15)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
