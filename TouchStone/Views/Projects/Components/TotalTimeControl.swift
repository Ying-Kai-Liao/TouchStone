import SwiftUI

/// Control for adjusting total project time in hours
struct TotalTimeControl: View {
    @Binding var totalHours: Int

    private let minHours: Int = 5
    private let maxHours: Int = 200
    private let step: Int = 5

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Total Project Time")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)

            HStack(spacing: DesignSystem.Spacing.xl) {
                // Minus button
                Button {
                    totalHours = max(minHours, totalHours - step)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(totalHours <= minHours ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(DesignSystem.Colors.background)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(totalHours <= minHours)

                // Hours display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(totalHours)")
                        .font(.system(size: 42, weight: .light, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .monospacedDigit()
                    Text("hours")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .frame(minWidth: 140)

                // Plus button
                Button {
                    totalHours = min(maxHours, totalHours + step)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(totalHours >= maxHours ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(DesignSystem.Colors.background)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(totalHours >= maxHours)
            }

            // Slider
            Slider(
                value: Binding(
                    get: { Double(totalHours) },
                    set: { totalHours = Int($0) }
                ),
                in: Double(minHours)...Double(maxHours),
                step: Double(step)
            )
            .tint(DesignSystem.Colors.textTertiary)
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
    }
}

#Preview {
    TotalTimeControl(totalHours: .constant(40))
        .padding()
        .background(DesignSystem.Colors.cardBackground)
}
