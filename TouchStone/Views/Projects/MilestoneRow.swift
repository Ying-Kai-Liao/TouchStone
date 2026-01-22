import SwiftUI
import SwiftData

/// A checkbox-style row for milestone-mode projects.
/// Displays milestone title, description, and completion status.
struct MilestoneRow: View {
    @Bindable var milestone: Milestone

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.3)) {
                    milestone.toggleCompletion()
                }
            } label: {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(milestone.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(milestone.isCompleted)
                    .foregroundStyle(milestone.isCompleted ? .secondary : .primary)

                if let description = milestone.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let completedAt = milestone.completedAt {
                    Text("Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Compact Milestone Row

/// A more compact milestone row for lists
struct CompactMilestoneRow: View {
    @Bindable var milestone: Milestone
    var onToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    milestone.toggleCompletion()
                    onToggle?()
                }
            } label: {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(milestone.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(milestone.title)
                .font(.subheadline)
                .strikethrough(milestone.isCompleted)
                .foregroundStyle(milestone.isCompleted ? .secondary : .primary)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Milestone Row") {
    VStack {
        MilestoneRow(milestone: Milestone(
            title: "Gather W2s and 1099s",
            descriptionText: "Collect all income documents from employers and banks"
        ))

        MilestoneRow(milestone: {
            let m = Milestone(
                title: "Complete federal return",
                descriptionText: "Fill out Form 1040 with all schedules"
            )
            m.markComplete()
            return m
        }())

        Divider()

        CompactMilestoneRow(milestone: Milestone(
            title: "Submit e-file"
        ))
    }
    .padding()
}
