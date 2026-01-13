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

/// Suggested session card with touch and focus actions
struct WaterFlowRow: View {
    let item: WorkflowItem
    let onTouch: (() -> Void)?
    let onFocus: (() -> Void)?

    @State private var isInFlow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Optional image header (for visual appeal)
            if isInFlow {
                ZStack(alignment: .bottomLeading) {
                    // Placeholder gradient for visual appeal
                    LinearGradient(
                        colors: [Color.teal.opacity(0.3), Color.blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("IN FLOW")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.teal)
                        .clipShape(Capsule())
                        .padding(12)
                }
            }

            // Main content
            HStack(alignment: .center, spacing: 16) {
                // Play/status icon
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: isInFlow ? "play.fill" : "circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.teal)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

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

                // Focus button
                if let onFocus = onFocus {
                    Button(action: onFocus) {
                        HStack(spacing: 4) {
                            Image(systemName: "scope")
                                .font(.caption)
                            Text("Focus")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // More menu
                Menu {
                    Button("Start Focus", action: { onFocus?() })
                    Button("Log Touch", action: { onTouch?() })
                    Button("Skip", role: .destructive, action: {})
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onTapGesture {
            onTouch?()
        }
        .onLongPressGesture {
            onFocus?()
        }
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

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        BreathingSpaceRow(minutes: 30)
        FlowPrepRow(minutes: 15)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
