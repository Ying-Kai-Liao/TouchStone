import SwiftUI
import SwiftData

// MARK: - Rules List View

/// Displays a list of daily rules (blocked time slots).
/// Users can toggle, edit, and delete rules from this view.
struct RulesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Rule.startHour) private var rules: [Rule]

    @State private var showAddRule = false
    @State private var editingRule: Rule?

    var body: some View {
        List {
            Section {
                ForEach(rules) { rule in
                    RuleRowView(rule: rule)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingRule = rule
                        }
                }
                .onDelete(perform: deleteRules)
            } header: {
                Text("Daily Rules")
            } footer: {
                Text("Sessions won't be scheduled during these time blocks.")
            }
        }
        .navigationTitle("Daily Rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddRule = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddRule) {
            NavigationStack {
                RuleFormView(rule: nil)
            }
        }
        .sheet(item: $editingRule) { rule in
            NavigationStack {
                RuleFormView(rule: rule)
            }
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rules[index])
        }
    }
}

// MARK: - Rule Row View

/// Displays a single rule with toggle and time info.
struct RuleRowView: View {
    @Bindable var rule: Rule

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(rule.isActive ? .primary : .secondary)

                HStack(spacing: 8) {
                    Text(rule.timeRangeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(rule.recurrenceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $rule.isActive)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        RulesListView()
    }
    .modelContainer(for: Rule.self, inMemory: true)
}
