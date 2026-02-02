import SwiftUI
import SwiftData

struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Project> { $0.isActive }) private var activeProjects: [Project]
    @Query private var allStones: [StoneEvent]
    @Query private var allContexts: [DayContext]

    private var prefs: UserPreferences { UserPreferences.shared }

    // Contexts active for this specific date
    private var activeContexts: [DayContext] {
        allContexts.filter { $0.appliesTo(date: date) }
    }

    @State private var stoneToDelete: StoneEvent?
    @State private var showDeleteAlert = false
    @State private var stoneToEdit: StoneEvent?
    @State private var contextToDelete: DayContext?
    @State private var showDeleteContextAlert = false
    @State private var contextToEdit: DayContext?
    @State private var dayState: DayState?
    @State private var showTimeAllocation = false
    @State private var showingAddContext = false

    let date: Date
    let stones: [StoneEvent]
    let onAddStone: () -> Void

    private let calendar = Calendar.current

    // Computed suggested sessions for this day
    private var suggestedSessions: [SuggestedSession] {
        dayState?.suggestedSessions ?? []
    }

    // Context-aware work suppression
    private var shouldSuppressWork: Bool {
        let mode = activeContexts.strictestWorkMode(for: date)
        return mode == .none || mode == .fixed
    }

    // Fixed task description if in fixed mode
    private var fixedTaskDescription: String? {
        activeContexts.fixedTask(for: date)
    }

    // Projects with deadlines on this day
    private var projectsDue: [Project] {
        PressureCalculator.projectsWithDeadline(on: date, projects: Array(activeProjects))
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
                .alert("Delete Stone", isPresented: $showDeleteAlert, presenting: stoneToDelete) { stone in
                    Button("Cancel", role: .cancel) { stoneToDelete = nil }
                    Button("Delete", role: .destructive) {
                        HapticService.delete()
                        deleteStone(stone)
                    }
                } message: { stone in
                    Text(stone.recurrence.type != .none
                         ? "This is a recurring event. Deleting it will remove all occurrences of \"\(stone.title)\"."
                         : "Are you sure you want to delete \"\(stone.title)\"?")
                }
                .alert("Delete Day Plan", isPresented: $showDeleteContextAlert, presenting: contextToDelete) { context in
                    Button("Cancel", role: .cancel) { contextToDelete = nil }
                    Button("Delete", role: .destructive) {
                        HapticService.delete()
                        deleteContext(context)
                    }
                } message: { context in
                    Text(context.durationDays > 1
                         ? "This day plan spans \(context.durationDays) days. Deleting it will remove \"\(context.name)\" from all those days."
                         : "Are you sure you want to delete \"\(context.name)\"?")
                }
                .sheet(item: $stoneToEdit) { stone in
                    StoneEditSheet(stone: stone, onSave: {})
                }
                .sheet(isPresented: $showingAddContext) {
                    NavigationStack { ContextFormView(context: nil, initialDate: date) }
                }
                .sheet(item: $contextToEdit) { context in
                    NavigationStack { ContextFormView(context: context, initialDate: date) }
                }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    private var mainContent: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                scrollContent
            }
            .onAppear { computeDayState() }
            .safeAreaInset(edge: .bottom) { addStoneButton }
        }
    }

    private var scrollContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            DayHeroHeader(
                date: date,
                stonesCount: stones.count,
                projects: Array(activeProjects),
                stones: Array(allStones),
                contexts: Array(allContexts),
                activeContexts: activeContexts
            )

            if !activeContexts.isEmpty {
                contextBanner
            }

            if !stones.isEmpty {
                stonesSection
            } else {
                emptyScheduleHint
            }

            if !projectsDue.isEmpty {
                DayProjectsDueSection(projects: projectsDue)
            }

            if !suggestedSessions.isEmpty && !shouldSuppressWork {
                DaySuggestedWorkSection(sessions: suggestedSessions)
            } else if shouldSuppressWork && !activeContexts.isEmpty {
                noWorkMessage
            }

            if let fixedTask = fixedTaskDescription {
                fixedTaskSection(task: fixedTask)
            }

            DayTimeAllocationSection(
                date: date,
                projects: Array(activeProjects),
                stones: Array(allStones),
                contexts: Array(allContexts),
                isExpanded: $showTimeAllocation
            )
            .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .padding(.bottom, 100)
    }

    private func deleteStone(_ stone: StoneEvent) {
        modelContext.delete(stone)
        stoneToDelete = nil
    }

    private func deleteContext(_ context: DayContext) {
        modelContext.delete(context)
        contextToDelete = nil
    }

    // MARK: - Compute Day State

    private func computeDayState() {
        let state = DayState(date: date)
        state.compute(
            stones: Array(allStones),
            projects: Array(activeProjects),
            contexts: Array(allContexts)
        )
        dayState = state
    }

    // MARK: - Stones Section

    private var emptyScheduleHint: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("SCHEDULE")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            Text("No events scheduled")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.lg)
    }

    private var stonesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("SCHEDULE")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            DayTimelineView(
                date: date,
                stones: stones,
                suggestedSessions: suggestedSessions,
                onStoneEdit: { stone in
                    stoneToEdit = stone
                },
                onStoneDelete: { stone in
                    HapticService.warning()
                    stoneToDelete = stone
                    showDeleteAlert = true
                }
            )
            .frame(height: 960) // 16 hours * 60pt per hour
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.bottom, DesignSystem.Spacing.xl)
    }

    private var addStoneButton: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Add Event button
            Button {
                onAddStone()
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add Event")
                        .font(DesignSystem.Typography.headline)
                }
                .foregroundStyle(DesignSystem.Colors.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                        .fill(DesignSystem.Colors.accent)
                )
            }

            // Day Plan button
            Button {
                showingAddContext = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 18))
                    Text("Day Plan")
                        .font(DesignSystem.Typography.headline)
                }
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.accent, lineWidth: 2)
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Context Banner

    private var contextBanner: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(activeContexts) { context in
                SwipeToDeleteRow(
                    onDelete: {
                        HapticService.warning()
                        contextToDelete = context
                        showDeleteContextAlert = true
                    }
                ) {
                    ContextBannerRow(context: context)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            contextToEdit = context
                        }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }

    // MARK: - No Work Message

    private var noWorkMessage: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 32))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("Day Off")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("No work sessions scheduled for this day.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
    }

    // MARK: - Fixed Task Section

    private func fixedTaskSection(task: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("TODAY'S FOCUS")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignSystem.Colors.accent)

                Text(task)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }
}

// MARK: - Stone Row View

struct StoneRowView: View {
    let stone: StoneEvent

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(stone.startTimeString)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(stone.endTimeString)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .frame(width: 70, alignment: .leading)

            // Event card
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(stone.title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(stone.durationMinutes) min")
                        .font(DesignSystem.Typography.caption)

                    if stone.recurrence.type != .none {
                        Image(systemName: "repeat")
                            .font(.caption)
                        Text(recurrenceLabel)
                            .font(DesignSystem.Typography.caption)
                    }
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
            )
        }
    }

    private var recurrenceLabel: String {
        switch stone.recurrence.type {
        case .none: return "One time"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .weekly: return "Weekly"
        case .custom:
            if let days = stone.recurrence.customDays {
                let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                return days.map { dayLabels[$0 - 1] }.joined(separator: ", ")
            }
            return "Custom"
        }
    }
}

// MARK: - Context Banner Row

struct ContextBannerRow: View {
    let context: DayContext

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: context.type.icon)
                .font(.system(size: 18))
                .foregroundStyle(DesignSystem.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(context.shortDescription)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Work mode indicator
            Text(context.workMode.displayName.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(context.workMode.color)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    Capsule()
                        .fill(context.workMode.color.opacity(0.15))
                )
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                .fill(DesignSystem.Colors.accent.opacity(0.1))
        )
    }
}

#Preview {
    @Previewable @State var stones: [StoneEvent] = []

    DayDetailView(
        date: Date(),
        stones: stones,
        onAddStone: {}
    )
    .modelContainer(for: [StoneEvent.self, Project.self, DayContext.self], inMemory: true)
}
