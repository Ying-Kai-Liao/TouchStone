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
        case .rest(let minutes):
            RestRow(minutes: minutes)
        }
    }
}

// MARK: - Stone Flow Row

/// Fixed event card with completion status
struct StoneFlowRow: View {
    let item: WorkflowItem

    private var isCompleted: Bool {
        item.status == .completed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            HStack(alignment: .center, spacing: 12) {
                // Stone details
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(isCompleted ? .secondary : .primary)

                    Text(item.timeRangeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Participant avatars (placeholder - can add real avatars later)
                if !isCompleted {
                    HStack(spacing: -8) {
                        Circle()
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text("👤")
                                    .font(.system(size: 14))
                            )
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text("👔")
                                    .font(.system(size: 14))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1.0)))
                .opacity(isCompleted ? 0.5 : 1)
        )
    }
}

// MARK: - Water Flow Row

/// Suggested session card with touch and focus actions.
/// Appears as ghost block (dashed, translucent) before touch, solid block after touch.
/// Active "IN FLOW" sessions display with a gradient header image.
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
        !hasTouchedToday && item.status != .inProgress
    }

    /// Whether this is the active "in flow" session
    private var isInFlow: Bool {
        item.status == .inProgress
    }

    private let cardBackground = Color(uiColor: UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1.0))

    var body: some View {
        // Whole block is tappable to touch
        Button(action: { onTouch?() }) {
            VStack(alignment: .leading, spacing: 0) {
                // Gradient header for in-flow sessions
                if isInFlow {
                    inFlowHeader
                }

                // Main content
                VStack(alignment: .leading, spacing: 8) {
                    // Title row with menu
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.primary.opacity(isGhost ? 0.6 : 1.0))
                                .multilineTextAlignment(.leading)

                            if let subtitle = item.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Three-dot menu
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    }

                    // Time and Focus button row
                    HStack(alignment: .center, spacing: 12) {
                        // Time with clock icon
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.timeRangeString)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Focus button - styled as teal pill
                        if let onFocus = onFocus {
                            Button(action: onFocus) {
                                HStack(spacing: 6) {
                                    Image(systemName: "scope")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Focus")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.teal)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(cardBackground.opacity(isGhost ? 0.5 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isGhost ? Color.teal.opacity(0.3) : Color.clear,
                        style: StrokeStyle(lineWidth: 1.5, dash: isGhost ? [6, 4] : [])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// Gradient header with "IN FLOW" badge for active sessions
    private var inFlowHeader: some View {
        ZStack(alignment: .topLeading) {
            // Gradient background simulating water/waves image
            LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.55, blue: 0.6),
                    Color(red: 0.5, green: 0.65, blue: 0.7),
                    Color(red: 0.55, green: 0.7, blue: 0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 100)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    topTrailingRadius: 16
                )
            )
            .overlay(
                // Subtle wave pattern overlay
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        WaveShape(offset: CGFloat(i) * 20, amplitude: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            .offset(y: CGFloat(i) * 15)
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        topTrailingRadius: 16
                    )
                )
            )

            // IN FLOW badge
            Text("IN FLOW")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.teal)
                )
                .padding(12)
        }
    }
}

/// Wave shape for decorative header
struct WaveShape: Shape {
    let offset: CGFloat
    let amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2

        path.move(to: CGPoint(x: 0, y: midY + offset))

        for x in stride(from: 0, through: width, by: 5) {
            let relativeX = x / width
            let y = midY + offset + sin(relativeX * .pi * 4) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

// MARK: - Breathing Space Row

/// Small bubble for breathing space between activities
struct BreathingSpaceRow: View {
    let minutes: Int

    var body: some View {
        HStack {
            Text("Breathing Space \u{00B7} \(minutes)m")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color(.systemGray))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(uiColor: UIColor(red: 0.22, green: 0.24, blue: 0.26, alpha: 1.0)))
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

// MARK: - Flow Prep Row

/// Small bubble for flow state preparation
struct FlowPrepRow: View {
    let minutes: Int

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("Flow State Prep \u{00B7} \(minutes)m")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(.systemGray))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.12))
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

// MARK: - Rest Row

/// Rest break between work sessions
struct RestRow: View {
    let minutes: Int

    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("Rest \u{00B7} \(minutes)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.1))
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

    private let cardBackground = Color(uiColor: UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1.0))

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row with reschedule button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let onReschedule = onReschedule {
                    Button(action: onReschedule) {
                        Text("Reschedule?")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(.systemGray))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Time info
            Text("Yesterday \u{00B7} 1h estimate")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        )
    }
}

// MARK: - Additional Project Row

/// A compact touch block for projects in the "MORE TO TOUCH" section.
/// Shows touch count (x0, x1, x2...) instead of checkmark.
struct AdditionalProjectRow: View {
    let project: Project
    let onTouch: () -> Void
    let onFocus: () -> Void

    private let cardBackground = Color(uiColor: UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1.0))

    /// Count how many times this project was touched today
    private var touchCountToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return project.touchLogs.filter { log in
            calendar.startOfDay(for: log.timestamp) == today
        }.count
    }

    var body: some View {
        // Whole block is tappable to touch
        Button(action: onTouch) {
            HStack(alignment: .center, spacing: 12) {
                // Touch count badge
                Text("x\(touchCountToday)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(touchCountToday > 0 ? .teal : Color(.systemGray))
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if let phase = project.currentPhase, !phase.isEmpty {
                        Text(phase)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Focus button - styled as teal pill to match WaterFlowRow
                Button(action: onFocus) {
                    HStack(spacing: 4) {
                        Image(systemName: "scope")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Focus")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.teal)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBackground)
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
