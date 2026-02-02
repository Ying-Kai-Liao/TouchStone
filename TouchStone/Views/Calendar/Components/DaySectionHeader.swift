import SwiftUI

// MARK: - Day Section Header

/// Reusable section header component for DayDetailView sections.
/// Matches the existing section header style: uppercase, caption bold font,
/// tertiary text color, letter tracking 1.
///
/// Example usage:
/// - "SCHEDULE"
/// - "DUE TODAY"
/// - "SUGGESTED WORK"
/// - "TIME ALLOCATION"
struct DaySectionHeader<TrailingContent: View>: View {
    let title: String
    let trailingContent: TrailingContent?

    init(title: String) where TrailingContent == EmptyView {
        self.title = title
        self.trailingContent = nil
    }

    init(title: String, @ViewBuilder trailing: () -> TrailingContent) {
        self.title = title
        self.trailingContent = trailing()
    }

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            Spacer()

            if let trailing = trailingContent {
                trailing
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        DaySectionHeader(title: "Schedule")
            .padding(.horizontal, DesignSystem.Spacing.xl)

        DaySectionHeader(title: "Due Today") {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.accent)
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)

        DaySectionHeader(title: "Suggested Work")
            .padding(.horizontal, DesignSystem.Spacing.xl)

        DaySectionHeader(title: "Time Allocation") {
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }
    .padding(.vertical, DesignSystem.Spacing.xl)
    .background(DesignSystem.Colors.background)
}
