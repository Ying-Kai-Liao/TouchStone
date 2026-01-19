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
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    if rules.isEmpty {
                        // Empty state
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 40))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                            Text("No time blocks")
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            Text("Add blocked time slots to prevent scheduling during certain hours.")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.xxl)
                    } else {
                        // Rules list
                        VStack(spacing: 0) {
                            ForEach(rules) { rule in
                                RuleRowView(rule: rule)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingRule = rule
                                    }

                                if rule.id != rules.last?.id {
                                    Divider()
                                        .background(DesignSystem.Colors.divider)
                                        .padding(.leading, DesignSystem.Spacing.lg)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                .fill(DesignSystem.Colors.cardBackground)
                        )
                    }

                    Text("Sessions won't be scheduled during these time blocks.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Time Blocks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddRule = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(DesignSystem.Colors.accent)
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
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(rule.title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(rule.isActive ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(rule.timeRangeString)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("·")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text(rule.recurrenceDescription)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $rule.isActive)
                .labelsHidden()
                .tint(DesignSystem.Colors.accent)
        }
        .padding(DesignSystem.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        RulesListView()
    }
    .modelContainer(for: Rule.self, inMemory: true)
}
