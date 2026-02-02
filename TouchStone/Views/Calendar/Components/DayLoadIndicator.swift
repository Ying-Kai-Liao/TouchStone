import SwiftUI

// MARK: - Day Load Indicator

/// A 64pt progress ring showing workload percentage for a day.
/// Features:
/// - Animated appearance with spring animation
/// - Color coded: accent (normal), warning (>80%), error (>100%)
/// - Percentage display in center with "load" label
/// - Uses rounded stroke caps similar to PieChartView
struct DayLoadIndicator: View {
    let loadPercentage: Double
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    init(loadPercentage: Double, size: CGFloat = 64) {
        self.loadPercentage = loadPercentage
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    DesignSystem.Colors.cardBackground,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: trimValue)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)

            // Center content
            VStack(spacing: 2) {
                Text("\(displayPercentage)%")
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundStyle(ringColor)

                Text("load")
                    .font(.system(size: size * 0.14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            animatedProgress = loadPercentage
        }
        .onChange(of: loadPercentage) { _, newValue in
            animatedProgress = newValue
        }
    }

    // MARK: - Computed Properties

    private var lineWidth: CGFloat {
        size * 0.12
    }

    /// Trim value for the progress ring (capped at 1.0 for visual)
    private var trimValue: CGFloat {
        min(1.0, animatedProgress)
    }

    /// Display percentage (can exceed 100%)
    private var displayPercentage: Int {
        Int(animatedProgress * 100)
    }

    /// Ring color based on load percentage
    private var ringColor: Color {
        if animatedProgress > 1.0 {
            return DesignSystem.Colors.error
        } else if animatedProgress > 0.8 {
            return DesignSystem.Colors.warning
        } else {
            return DesignSystem.Colors.accent
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DesignSystem.Spacing.xl) {
        HStack(spacing: DesignSystem.Spacing.xl) {
            DayLoadIndicator(loadPercentage: 0.45)
            DayLoadIndicator(loadPercentage: 0.78)
        }
        HStack(spacing: DesignSystem.Spacing.xl) {
            DayLoadIndicator(loadPercentage: 0.85)
            DayLoadIndicator(loadPercentage: 1.15)
        }
    }
    .padding(DesignSystem.Spacing.xl)
    .background(DesignSystem.Colors.background)
}
