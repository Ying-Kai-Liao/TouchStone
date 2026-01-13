import SwiftUI

// MARK: - Flow Timeline View

/// Displays the daily workflow as a vertical timeline stream.
/// Shows stones (fixed events) and waters (suggested sessions) merged chronologically.
struct FlowTimelineView: View {
    let items: [WorkflowItem]
    let onTouch: (Project) -> Void
    let onFocus: (Project) -> Void

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    TimelineItemContainer(
                        item: item,
                        isFirst: index == 0,
                        isLast: index == items.count - 1,
                        onTouch: { project in onTouch(project) },
                        onFocus: { project in onFocus(project) }
                    )
                }

                // End of stream indicator
                endOfStreamIndicator
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "water.waves")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Your flow is clear")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("No scheduled events or suggested sessions")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var endOfStreamIndicator: some View {
        VStack(spacing: 8) {
            // Dots
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.top, 16)

            Text("END OF STREAM")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
                .tracking(1)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Timeline Item Container

/// Wraps each flow item with the timeline connector line
struct TimelineItemContainer: View {
    let item: WorkflowItem
    let isFirst: Bool
    let isLast: Bool
    let onTouch: (Project) -> Void
    let onFocus: (Project) -> Void

    private var lineColor: Color {
        switch item.status {
        case .completed:
            return .green.opacity(0.5)
        case .inProgress:
            return .teal
        case .upcoming, .suggested:
            return Color(.systemGray4)
        case .overdue:
            return .orange.opacity(0.5)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Timeline connector
            timelineConnector
                .frame(width: 20)

            // Content
            FlowItemRow(
                item: item,
                onTouch: item.project.map { project in { onTouch(project) } },
                onFocus: item.project.map { project in { onFocus(project) } }
            )
            .padding(.leading, 8)
            .padding(.trailing, 16)
            .padding(.vertical, item.isBreathingSpace || item.isFlowPrep ? 4 : 8)
        }
    }

    private var timelineConnector: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Vertical line
                if !isLast {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 2)
                        .offset(x: 9) // Center in the 20pt width
                }

                // Top connector (for non-first items)
                if !isFirst {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 2, height: 8)
                        .offset(x: 9)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        FlowTimelineView(
            items: [],
            onTouch: { _ in },
            onFocus: { _ in }
        )
    }
    .background(Color(.systemBackground))
}
