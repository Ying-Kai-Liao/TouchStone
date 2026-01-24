import SwiftUI

// MARK: - Work Today Prompt View

/// A bottom overlay component that asks "Do you want to work today?"
/// This is the gate that starts the day - recording when the user begins.
/// The allocation shown is just a suggestion; this prompt enables touch tracking.
struct WorkTodayPromptView: View {
    let onConfirmWork: () -> Void
    let onDeclineWork: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Text("Do you want to work today?")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            HStack(spacing: DesignSystem.Spacing.lg) {
                // Decline button
                Button(action: onDeclineWork) {
                    Text("Not today")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.cardBackgroundLight)
                        .clipShape(Capsule())
                }

                // Confirm button
                Button(action: onConfirmWork) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("Let's go")
                            .fontWeight(.semibold)
                    }
                    .font(DesignSystem.Typography.callout)
                    .foregroundStyle(DesignSystem.Colors.background)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.accent)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge)
                .fill(DesignSystem.Colors.cardBackground)
                .shadow(color: .black.opacity(0.2), radius: 10, y: -5)
        )
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        DesignSystem.Colors.background
            .ignoresSafeArea()

        VStack {
            Spacer()
            WorkTodayPromptView(
                onConfirmWork: { print("Work confirmed") },
                onDeclineWork: { print("Work declined") }
            )
        }
    }
}
