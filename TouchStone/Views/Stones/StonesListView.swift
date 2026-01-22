import SwiftUI
import SwiftData

struct StonesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoneEvent.createdAt, order: .reverse) private var stones: [StoneEvent]

    @State private var showingAddSheet = false
    @State private var showingImportSheet = false
    @State private var stoneToDelete: StoneEvent?
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom header
                    headerView
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // Content
                    if stones.isEmpty {
                        emptyState
                    } else {
                        stonesList
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSheet) {
                StoneChatInputView(initialDate: nil)
            }
            .alert("Delete Stone", isPresented: $showDeleteAlert, presenting: stoneToDelete) { stone in
                Button("Cancel", role: .cancel) {
                    stoneToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    modelContext.delete(stone)
                    stoneToDelete = nil
                }
            } message: { stone in
                Text("Delete \"\(stone.title)\"? This cannot be undone.")
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportEventsView { importedStones in
                    for stone in importedStones {
                        modelContext.insert(stone)
                    }
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center) {
            Text("Stones")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            // Import from Calendar button
            Button {
                showingImportSheet = true
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            }

            // Add manually button
            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Stones List

    private var stonesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(stones) { stone in
                    SwipeToDeleteRow(
                        onDelete: {
                            stoneToDelete = stone
                            showDeleteAlert = true
                        }
                    ) {
                        StoneCard(stone: stone)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("No Stones")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text("Stones are fixed events that cannot move.\nAdd your meetings, appointments, and commitments.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    showingAddSheet = true
                } label: {
                    Text("Add Stone")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.accent.opacity(0.15))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
                        )
                }

                Button {
                    showingImportSheet = true
                } label: {
                    Label("Import", systemImage: "calendar.badge.plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.cardBackground)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.background)
    }

    private func deleteStones(at offsets: IndexSet, from list: [StoneEvent]) {
        for index in offsets {
            modelContext.delete(list[index])
        }
    }
}

// MARK: - Stone Card

struct StoneCard: View {
    let stone: StoneEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(stone.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            // Time and recurrence
            HStack(spacing: 16) {
                // Time
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    Text(stone.timeRangeString)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                // Recurrence badge
                Text(recurrenceLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.accent.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }

    private var recurrenceLabel: String {
        switch stone.recurrence.type {
        case .none: return "Once"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .weekly: return "Weekly"
        case .custom:
            let days = stone.recurrence.customDays ?? []
            let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
            let selected = days.sorted().map { dayNames[$0 - 1] }.joined(separator: "")
            return selected
        }
    }
}

struct StoneEventRow: View {
    let stone: StoneEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stone.title)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                Text(stone.timeRangeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .foregroundStyle(.tertiary)

                Text(recurrenceLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var recurrenceLabel: String {
        switch stone.recurrence.type {
        case .none: return "One time"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .weekly: return "Weekly"
        case .custom:
            let days = stone.recurrence.customDays ?? []
            let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
            let selected = days.sorted().map { dayNames[$0 - 1] }.joined(separator: ", ")
            return selected
        }
    }
}

#Preview {
    StonesListView()
        .modelContainer(for: StoneEvent.self, inMemory: true)
}
