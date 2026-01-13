import SwiftUI
import SwiftData

// MARK: - Today Flow View

/// Main workflow view showing the daily schedule as a merged timeline.
/// Displays stones (fixed events) and waters (suggested sessions) in chronological order.
struct TodayFlowView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var allStones: [StoneEvent]

    @Query(filter: #Predicate<Project> { $0.isActive }, sort: \Project.createdAt, order: .reverse)
    private var activeProjects: [Project]

    @State private var dayState = DayState()
    @State private var selectedDate = Date()
    @State private var showZenMode = false
    @State private var focusProject: Project?
    @State private var lastTouch: TouchLog?
    @State private var showUndoToast = false
    @State private var showAddStone = false
    @State private var showSpeechInput = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(uiColor: UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1.0))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Date tabs
                    dateTabsView
                        .padding(.top, 16)

                    // Main content
                    ScrollView {
                        FlowTimelineView(
                            items: dayState.workflowItems,
                            onTouch: touchProject,
                            onFocus: { project in focusProject = project }
                        )
                        .padding(.top, 16)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear { computeDayState() }
            .onChange(of: allStones.count) { computeDayState() }
            .onChange(of: selectedDate) { computeDayState() }
            .overlay(alignment: .bottom) { undoToast }
            .sheet(isPresented: $showAddStone) {
                StoneEventFormView(onSave: { stone in
                    modelContext.insert(stone)
                    computeDayState()
                })
            }
            .sheet(isPresented: $showSpeechInput) {
                SpeechStoneInputView(initialDate: selectedDate)
            }
            .sheet(item: $focusProject) { project in
                FocusModeView(project: project) {
                    focusProject = nil
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center) {
            // Menu button
            Button {
                showAddStone = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Flow")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(headerDateString)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
            }
            .padding(.leading, 8)

            Spacer()

            // Zen Mode button
            Button {
                showZenMode = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                    Text("Zen Mode")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                )
            }
        }
    }

    private var headerDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d \u{00B7} EEEE"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Date Tabs

    private var dateTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(upcomingDates, id: \.self) { date in
                    DateTabButton(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var upcomingDates: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))
        }
    }

    // MARK: - Undo Toast

    @ViewBuilder
    private var undoToast: some View {
        if showUndoToast, let touch = lastTouch {
            HStack {
                Text("Logged touch for \(touch.projectTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Button("Undo") {
                    undoTouch()
                }
                .fontWeight(.semibold)
                .foregroundStyle(.teal)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6).opacity(0.9))
            )
            .shadow(radius: 4)
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func computeDayState() {
        dayState = DayState(date: selectedDate)
        dayState.compute(stones: allStones, projects: activeProjects)
    }

    private func touchProject(_ project: Project) {
        let touch = TouchLog(project: project)
        modelContext.insert(touch)
        lastTouch = touch

        withAnimation {
            showUndoToast = true
        }

        // Hide toast after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                if lastTouch?.id == touch.id {
                    showUndoToast = false
                }
            }
        }

        // Recompute to update suggested sessions
        computeDayState()
    }

    private func undoTouch() {
        if let touch = lastTouch {
            modelContext.delete(touch)
            withAnimation {
                showUndoToast = false
                lastTouch = nil
            }
            computeDayState()
        }
    }
}

// MARK: - Date Tab Button

struct DateTabButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: action) {
            Text(buttonLabel)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .teal : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.teal.opacity(0.2) : Color.clear)
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? Color.teal.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var buttonLabel: String {
        if isToday {
            return "Today"
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        if calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    TodayFlowView()
        .modelContainer(for: [Project.self, StoneEvent.self, TouchLog.self], inMemory: true)
}
