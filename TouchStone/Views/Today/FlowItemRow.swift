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
            BreakRow(minutes: minutes)
        case .meal(let rule):
            MealRow(rule: rule, item: item)
        }
    }
}

// MARK: - Stone Flow Row

/// Fixed event card with completion status
/// Expands when tapped by user
struct StoneFlowRow: View {
    let item: WorkflowItem

    @State private var isExpanded: Bool = false

    private var isCompleted: Bool {
        item.status == .completed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Stone image header when expanded - with padding inside card
            if isExpanded {
                stoneHeader
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
            }

            // Content - expanded or compact based on tap
            if isExpanded {
                // Full content for expanded stone
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(item.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    // Recurrence info if applicable
                    if let stoneInstance = item.stoneInstance {
                        let recurrence = stoneInstance.event.recurrence
                        if recurrence.type != .none {
                            Text(recurrenceLabel(for: recurrence))
                                .font(.system(size: 15))
                                .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.9))
                        }
                    }

                    // Time row at bottom
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.7))
                        Text(item.timeRangeString)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.8))

                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.5))

                        Text("\(item.durationMinutes) min")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            } else {
                // Compact content - title on top, time below, no subtitle
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(isCompleted ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
                        .strikethrough(isCompleted, color: DesignSystem.Colors.textTertiary)

                    Text(item.timeRangeString)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
                .opacity(isCompleted ? 0.5 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticService.expand()
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        }
    }

    /// Stone/rock gradient header for active events
    private var stoneHeader: some View {
        ZStack(alignment: .topLeading) {
            // Gradient background simulating stone/rock texture
            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.30, blue: 0.32),
                    Color(red: 0.38, green: 0.40, blue: 0.42),
                    Color(red: 0.45, green: 0.47, blue: 0.50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card - 8, style: .continuous))
            .overlay(
                // Stone texture pattern
                ZStack {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(0.03))
                            .frame(width: CGFloat(30 + i * 15), height: CGFloat(30 + i * 15))
                            .offset(
                                x: CGFloat(i * 40 - 60),
                                y: CGFloat(i * 10 - 20)
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card - 8, style: .continuous))
            )

            // STONE badge - glassy style
            Text("STONE")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color(red: 0.5, green: 0.52, blue: 0.55).opacity(0.35))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
                .padding(12)
        }
    }

    private func recurrenceLabel(for recurrence: RecurrencePattern) -> String {
        switch recurrence.type {
        case .none: return ""
        case .daily: return "Repeats daily"
        case .weekdays: return "Repeats on weekdays"
        case .weekends: return "Repeats on weekends"
        case .weekly: return "Repeats weekly"
        case .custom: return "Custom schedule"
        }
    }
}

// MARK: - Water Flow Row

/// Suggested session card with touch and focus actions.
/// - Ghost block (dashed, translucent) when not touched today - tap to touch
/// - Solid block when touched today - tap to expand/collapse
struct WaterFlowRow: View {
    let item: WorkflowItem
    let onTouch: (() -> Void)?
    let onFocus: (() -> Void)?

    @State private var isExpanded: Bool = false

    /// Auto-expand if currently in progress
    private var isInProgress: Bool {
        item.status == .inProgress
    }

    /// Check if this project was touched today
    private var hasTouchedToday: Bool {
        guard let project = item.project else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return project.touchLogs.contains { log in
            calendar.startOfDay(for: log.timestamp) == today
        }
    }

    /// Ghost styling for untouched items
    private var isGhost: Bool {
        !hasTouchedToday
    }

    /// Check if this item is completed
    private var isCompleted: Bool {
        item.status == .completed
    }

    var body: some View {
        // Ghost blocks: tap to touch
        // Non-ghost blocks: tap to expand/collapse
        Button {
            if isGhost {
                // Haptic handled in TodayFlowView.performTouch
                onTouch?()
            } else {
                HapticService.expand()
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Water image header when expanded - with padding inside card
            if isExpanded {
                waterHeader
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
            }

            // Content - expanded or compact based on tap
            if isExpanded {
                // Full content for expanded water block
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(item.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    // Description - show phase mental rule or next milestone
                    if let project = item.project {
                        if project.isPhaseMode, let phase = project.activePhase, let rule = phase.mentalRule, !rule.isEmpty {
                            Text(rule)
                                .font(.system(size: 15))
                                .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.9))
                                .lineSpacing(4)
                        } else if project.isMilestoneMode, let milestone = project.nextMilestone {
                            Text(milestone.title)
                                .font(.system(size: 15))
                                .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.9))
                                .lineSpacing(4)
                        } else if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.system(size: 15))
                                .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.9))
                                .lineSpacing(4)
                        }
                    } else if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 15))
                            .foregroundStyle(DesignSystem.Colors.textSecondary.opacity(0.9))
                            .lineSpacing(4)
                    }

                    // Time and action button row
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.7))
                            Text(item.timeRangeString)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.8))
                        }

                        Spacer()

                        // Action button - Pause style pill
                        if let onFocus = onFocus {
                            Button {
                                HapticService.buttonPress()
                                onFocus()
                            } label: {
                                Text("Focus")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.4), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            } else {
                // Compact content - title on top, time below, no subtitle
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(isCompleted ? DesignSystem.Colors.textTertiary : (isGhost ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary))
                        .strikethrough(isCompleted, color: DesignSystem.Colors.textTertiary)

                    Text(item.timeRangeString)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground.opacity(isCompleted ? 0.5 : (isGhost ? 0.6 : 1)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .strokeBorder(
                    DesignSystem.Colors.textTertiary.opacity(isGhost && !isCompleted ? 0.3 : 0.2),
                    lineWidth: 1
                )
        )
        .onAppear {
            // Auto-expand if currently in progress
            if isInProgress {
                isExpanded = true
            }
        }
    }

    /// Gradient header with "ACTIVE FLOW" badge for active sessions
    private var waterHeader: some View {
        ZStack(alignment: .topLeading) {
            // Gradient background simulating water/waves image
            LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.50, blue: 0.55),
                    Color(red: 0.45, green: 0.58, blue: 0.62),
                    Color(red: 0.50, green: 0.62, blue: 0.68)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card - 8, style: .continuous))
            .overlay(
                // Subtle wave pattern overlay
                ZStack {
                    ForEach(0..<5, id: \.self) { i in
                        WaveShape(offset: CGFloat(i) * 12, amplitude: 5)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            .offset(y: CGFloat(i) * 10 + 50)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card - 8, style: .continuous))
            )

            // ACTIVE FLOW badge - white glassy style
            Text("ACTIVE FLOW")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.2))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
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
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.cardBackgroundLight)
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
                    .foregroundStyle(DesignSystem.Colors.badge)
                Text("Flow State Prep \u{00B7} \(minutes)m")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.badgeBackground)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

// MARK: - Break Row

/// Break between work sessions (renamed from Rest)
struct BreakRow: View {
    let minutes: Int

    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.badge)
                Text("Break \u{00B7} \(minutes)m")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.badgeBackground)
            )
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Meal Row

/// Meal time badge (lunch, dinner) from rules
struct MealRow: View {
    let rule: Rule
    let item: WorkflowItem

    /// Icon for the meal type
    private var mealIcon: String {
        let title = rule.title.lowercased()
        if title.contains("lunch") {
            return "sun.max.fill"
        } else if title.contains("dinner") {
            return "moon.stars.fill"
        } else if title.contains("breakfast") {
            return "sunrise.fill"
        } else {
            return "fork.knife"
        }
    }

    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: mealIcon)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.badge)
                Text(rule.title)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Text("\u{00B7}")
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                Text(item.timeRangeString)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.badgeBackground)
            )
            .overlay(
                Capsule()
                    .strokeBorder(DesignSystem.Colors.badgeBorder, lineWidth: 1)
            )
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Overdue Item Row

/// Row for items that are past due and not completed
struct OverdueItemRow: View {
    let item: WorkflowItem
    let onReschedule: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row with reschedule button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.callout)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                if let onReschedule = onReschedule {
                    Button(action: onReschedule) {
                        Text("Reschedule?")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Time info
            Text("Yesterday \u{00B7} 1h estimate")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
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
                    .foregroundStyle(touchCountToday > 0 ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    if let phase = project.currentPhase, !phase.isEmpty {
                        Text(phase)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                // Play button
                Button {
                    HapticService.buttonPress()
                    onFocus()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.accent.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
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
        BreakRow(minutes: 10)
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
