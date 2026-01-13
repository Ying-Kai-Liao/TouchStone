import SwiftUI
import SwiftData

struct StonesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoneEvent.createdAt, order: .reverse) private var stones: [StoneEvent]

    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if stones.isEmpty {
                    emptyState
                } else {
                    stonesList
                }
            }
            .navigationTitle("Stones")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                StoneEventFormView { stone in
                    modelContext.insert(stone)
                }
            }
        }
    }

    private var stonesList: some View {
        List {
            ForEach(stones) { stone in
                StoneEventRow(stone: stone)
            }
            .onDelete { indexSet in
                deleteStones(at: indexSet, from: stones)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Stones", systemImage: "clock")
        } description: {
            Text("Stones are fixed events that cannot move.\nAdd your meetings, appointments, and commitments.")
        } actions: {
            Button("Add Stone") {
                showingAddSheet = true
            }
        }
    }

    private func deleteStones(at offsets: IndexSet, from list: [StoneEvent]) {
        for index in offsets {
            modelContext.delete(list[index])
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
