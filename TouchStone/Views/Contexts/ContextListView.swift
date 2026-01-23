import SwiftUI
import SwiftData

// MARK: - Context List View

/// Displays a list of day contexts (holidays, vacations, events).
/// Users can add, edit, and delete contexts from this view.
struct ContextListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayContext.startDate, order: .forward) private var contexts: [DayContext]

    @State private var showAddContext = false
    @State private var editingContext: DayContext?

    private let calendar = Calendar.current

    // Separate upcoming/active from past contexts
    private var activeContexts: [DayContext] {
        let today = calendar.startOfDay(for: Date())
        return contexts.filter { $0.endDate >= today }
    }

    private var pastContexts: [DayContext] {
        let today = calendar.startOfDay(for: Date())
        return contexts.filter { $0.endDate < today }
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    if contexts.isEmpty {
                        emptyState
                    } else {
                        // Active/Upcoming contexts
                        if !activeContexts.isEmpty {
                            contextSection(title: "UPCOMING", contexts: activeContexts)
                        }

                        // Past contexts
                        if !pastContexts.isEmpty {
                            contextSection(title: "PAST", contexts: pastContexts)
                        }
                    }

                    helpText
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .navigationTitle("Day Plans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddContext = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
        .sheet(isPresented: $showAddContext) {
            NavigationStack {
                ContextFormView(context: nil)
            }
        }
        .sheet(item: $editingContext) { context in
            NavigationStack {
                ContextFormView(context: context)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("No day plans")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text("Add holidays, vacations, or other special days that affect your work schedule.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxl)
    }

    // MARK: - Context Section

    private func contextSection(title: String, contexts: [DayContext]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.captionBold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            VStack(spacing: 0) {
                ForEach(contexts) { context in
                    ContextRowView(context: context, onDelete: {
                        deleteContext(context)
                    })
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingContext = context
                    }

                    if context.id != contexts.last?.id {
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
    }

    // MARK: - Help Text

    private var helpText: some View {
        Text("Day plans affect how work is scheduled. Use them to mark holidays, vacations, or days with reduced capacity.")
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .padding(.horizontal, DesignSystem.Spacing.sm)
    }

    // MARK: - Actions

    private func deleteContext(_ context: DayContext) {
        modelContext.delete(context)
        do {
            try modelContext.save()
        } catch {
            // Re-insert the context on failure
            modelContext.insert(context)
        }
    }
}

// MARK: - Context Row View

struct ContextRowView: View {
    let context: DayContext
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Type icon
            Image(systemName: context.type.icon)
                .font(.system(size: 20))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(context.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(context.dateRangeString)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("·")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text(context.shortDescription)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            // Work mode badge
            Text(context.workMode.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(context.workMode.color)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    Capsule()
                        .fill(context.workMode.color.opacity(0.15))
                )

            // Delete button
            Button {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.lg)
        .alert("Delete Context", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(context.name)\"?")
        }
    }
}

#Preview {
    NavigationStack {
        ContextListView()
    }
    .modelContainer(for: DayContext.self, inMemory: true)
}
