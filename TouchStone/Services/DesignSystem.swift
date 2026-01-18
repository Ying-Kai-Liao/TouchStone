import SwiftUI

// MARK: - Design System

/// Central design system for the app's visual language
enum DesignSystem {

    // MARK: - Colors

    enum Colors {
        // Background colors
        static let background = Color(red: 0.10, green: 0.14, blue: 0.12)
        static let backgroundLight = Color(red: 0.12, green: 0.16, blue: 0.14)
        static let cardBackground = Color(red: 0.14, green: 0.18, blue: 0.16)
        static let cardBackgroundLight = Color(red: 0.16, green: 0.20, blue: 0.18)

        // Accent colors
        static let accent = Color(red: 0.65, green: 0.78, blue: 0.65)  // Sage green
        static let accentMuted = Color(red: 0.55, green: 0.68, blue: 0.55)

        // Text colors
        static let textPrimary = Color.white.opacity(0.9)
        static let textSecondary = Color.white.opacity(0.6)
        static let textTertiary = Color.white.opacity(0.4)

        // Status colors
        static let success = Color(red: 0.55, green: 0.75, blue: 0.55)
        static let warning = Color(red: 0.85, green: 0.70, blue: 0.45)
        static let error = Color(red: 0.85, green: 0.45, blue: 0.45)

        // Category colors
        static let focus = Color(red: 0.55, green: 0.70, blue: 0.75)
        static let deep = Color(red: 0.60, green: 0.65, blue: 0.55)
        static let social = Color(red: 0.75, green: 0.65, blue: 0.55)

        // Energy gradient colors (for heatmap)
        static let energyStill = Color(red: 0.25, green: 0.28, blue: 0.26)
        static let energyEase = Color(red: 0.45, green: 0.55, blue: 0.45)
        static let energyFlow = Color(red: 0.55, green: 0.65, blue: 0.60)
        static let energyPower = Color(red: 0.60, green: 0.70, blue: 0.65)
        static let energyPeak = Color(red: 0.55, green: 0.70, blue: 0.75)
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle = Font.system(size: 32, weight: .bold)
        static let title = Font.system(size: 24, weight: .semibold)
        static let title2 = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let callout = Font.system(size: 14, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
        static let captionBold = Font.system(size: 12, weight: .semibold)

        // Stat numbers
        static let statLarge = Font.system(size: 36, weight: .bold, design: .rounded)
        static let statMedium = Font.system(size: 28, weight: .bold, design: .rounded)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
        static let circular: CGFloat = 100
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
    }

    func cardStyleLight() -> some View {
        self
            .background(DesignSystem.Colors.cardBackgroundLight)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
    }

    func sectionHeader() -> some View {
        self
            .font(DesignSystem.Typography.captionBold)
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .tracking(1.5)
    }
}

// MARK: - Custom Button Styles

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundStyle(DesignSystem.Colors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct CircleButtonStyle: ButtonStyle {
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
