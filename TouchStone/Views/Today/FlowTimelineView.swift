import SwiftUI

// MARK: - Flow Timeline View

/// Displays the daily workflow as a vertical timeline stream.
/// Shows stones (fixed events) and waters (suggested sessions) merged chronologically.
/// Also displays additional projects not in the scheduled flow at the bottom.
struct FlowTimelineView: View {
    let items: [WorkflowItem]
    let additionalProjects: [Project]
    let isToday: Bool  // Whether viewing today's date
    let onTouch: (Project) -> Void
    let onFocus: (Project) -> Void
    let onDelete: ((WorkflowItem) -> Void)?
    let onDeleteStone: ((StoneEvent) -> Void)?
    let onEditMode: (() -> Void)?

    @State private var showMoreToTouch = false  // Collapsed by default

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty && additionalProjects.isEmpty {
                emptyState
            } else {
                // Scheduled flow items
                if !items.isEmpty {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        TimelineItemContainer(
                            item: item,
                            isFirst: index == 0,
                            isLast: index == items.count - 1,
                            onTouch: { project in onTouch(project) },
                            onFocus: { project in onFocus(project) },
                            onDelete: item.isWater ? { onDelete?(item) } : (item.isStone ? { if let stone = item.stoneInstance?.event { onDeleteStone?(stone) } } : nil),
                            onEditMode: item.isWater ? onEditMode : nil
                        )
                    }

                    // End of stream indicator
                    endOfStreamIndicator
                }

                // Additional projects section - only for today
                if isToday && !additionalProjects.isEmpty {
                    additionalProjectsSection
                }
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
        VStack(spacing: 12) {
            // Dots
            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.top, 20)

            Text("END OF STREAM")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color(.systemGray2))
                .tracking(2)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var additionalProjectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header - tappable to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMoreToTouch.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: showMoreToTouch ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(.systemGray2))

                    Text("MORE TO TOUCH")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(.systemGray2))
                        .tracking(2)

                    Text("(\(additionalProjects.count))")
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray3))

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Project blocks - only show when expanded
            if showMoreToTouch {
                VStack(spacing: 10) {
                    ForEach(additionalProjects) { project in
                        AdditionalProjectRow(
                            project: project,
                            onTouch: { onTouch(project) },
                            onFocus: { onFocus(project) }
                        )
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Timeline Item Container

/// Wraps each flow item with the timeline connector line and status indicator
struct TimelineItemContainer: View {
    let item: WorkflowItem
    let isFirst: Bool
    let isLast: Bool
    let onTouch: (Project) -> Void
    let onFocus: (Project) -> Void
    let onDelete: (() -> Void)?
    let onEditMode: (() -> Void)?

    // Use @State instead of @GestureState to prevent flashing on gesture end
    @State private var dragOffset: CGFloat = 0
    @State private var currentOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var showDeleteConfirm = false

    private let deleteThreshold: CGFloat = -80
    private let swipeSnapThreshold: CGFloat = -40

    private var swipeOffset: CGFloat {
        currentOffset + dragOffset
    }

    private var lineColor: Color {
        switch item.status {
        case .completed:
            return Color(.systemGray4)
        case .inProgress:
            return Color(.systemGray4)
        case .upcoming, .suggested:
            return Color(.systemGray4)
        case .overdue:
            return Color(.systemGray4)
        }
    }

    private var statusIcon: String {
        switch item.status {
        case .completed:
            return "checkmark"
        case .inProgress:
            return "play.fill"
        case .upcoming, .suggested:
            return "circle"
        case .overdue:
            return "arrow.counterclockwise"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .completed:
            return UserPreferences.shared.accentColor
        case .inProgress:
            return UserPreferences.shared.accentColor
        case .upcoming, .suggested:
            return Color(.systemGray3)
        case .overdue:
            return .orange
        }
    }

    /// Whether this is a transition item (breathing space, flow prep, or rest)
    private var isTransitionItem: Bool {
        item.isBreathingSpace || item.isFlowPrep || item.isRest
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button - always rendered, revealed by content sliding
            if onDelete != nil {
                deleteButton
                    .opacity(swipeOffset < 0 ? 1 : 0)
            }

            // Main content with swipe gesture
            HStack(alignment: .top, spacing: 0) {
                // Timeline with status indicator
                timelineWithIndicator
                    .frame(width: 56)

                // Content
                FlowItemRow(
                    item: item,
                    onTouch: item.project.map { project in { onTouch(project) } },
                    onFocus: item.project.map { project in { onFocus(project) } }
                )
                .padding(.trailing, 16)
                .padding(.vertical, isTransitionItem ? 4 : 12)
            }
            .background(Color(uiColor: UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1.0)))
            .offset(x: swipeOffset)
            .highPriorityGesture(swipeGesture)
            .simultaneousGesture(longPressGesture)
        }
        .clipped()
        .confirmationDialog("Remove from flow?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentOffset = 0
                }
                onDelete?()
            }
            Button("Cancel", role: .cancel) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentOffset = 0
                }
            }
        } message: {
            Text("This will remove the session from today's schedule.")
        }
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard onDelete != nil else { return }

                // Only start tracking if horizontal movement is dominant (reduces ScrollView conflict)
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                if !isDragging && !isHorizontal {
                    return
                }
                isDragging = true

                let translation = value.translation.width
                // Only allow left swipe (negative translation) or swipe back when open
                if translation < 0 || currentOffset < 0 {
                    let raw = currentOffset + translation
                    // Rubber band effect at limits
                    if raw > 0 {
                        dragOffset = -currentOffset + raw * 0.3
                    } else if raw < deleteThreshold * 1.2 {
                        let overshoot = raw - deleteThreshold * 1.2
                        dragOffset = -currentOffset + deleteThreshold * 1.2 + overshoot * 0.3
                    } else {
                        dragOffset = translation
                    }
                }
            }
            .onEnded { value in
                guard onDelete != nil else { return }
                isDragging = false

                let finalOffset = currentOffset + dragOffset
                let velocity = value.predictedEndTranslation.width - value.translation.width
                let projected = finalOffset + velocity * 0.3

                // Animate both dragOffset reset AND currentOffset change together
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    dragOffset = 0  // Reset drag offset with animation (fixes flashing)
                    if projected < swipeSnapThreshold {
                        // Snap to show delete button
                        currentOffset = deleteThreshold
                    } else {
                        // Snap back
                        currentOffset = 0
                    }
                }
            }
    }

    // MARK: - Long Press Gesture

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                guard onEditMode != nil else { return }
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onEditMode?()
            }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            VStack {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Remove")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .frame(width: abs(deleteThreshold))
            .frame(maxHeight: .infinity)
            .background(Color.red.opacity(0.9))
        }
        .buttonStyle(.plain)
    }

    private var timelineWithIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Vertical line - continuous
                Rectangle()
                    .fill(lineColor.opacity(0.4))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .offset(x: 24) // Center of the 56pt width

                // Status indicator (only for non-transition items)
                if !isTransitionItem {
                    statusIndicator
                        .offset(x: 0, y: 14) // Position at top of content
                }
            }
        }
    }

    private var statusIndicator: some View {
        ZStack {
            // Outer circle background
            Circle()
                .fill(Color(uiColor: UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1.0)))
                .frame(width: 50, height: 50)

            // Status circle
            Circle()
                .fill(statusColor.opacity(item.status == .completed ? 0.15 : 0.2))
                .frame(width: 44, height: 44)

            // Inner circle for upcoming/suggested (empty circle style)
            if item.status == .upcoming || item.status == .suggested {
                Circle()
                    .strokeBorder(Color(.systemGray3), lineWidth: 2)
                    .frame(width: 32, height: 32)
            } else {
                // Icon for other states
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        FlowTimelineView(
            items: [],
            additionalProjects: [],
            isToday: true,
            onTouch: { _ in },
            onFocus: { _ in },
            onDelete: nil,
            onDeleteStone: nil,
            onEditMode: nil
        )
    }
    .background(Color(.systemBackground))
}
