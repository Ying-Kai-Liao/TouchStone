import SwiftUI

// MARK: - Design System

/// Central design system for the app's visual language
/// Supports both light and dark appearance modes
enum DesignSystem {

    // MARK: - Colors

    enum Colors {
        // Helper to check if we're in dark mode
        private static var isDarkMode: Bool {
            switch UserPreferences.shared.appearanceMode {
            case .dark:
                return true
            case .light:
                return false
            case .system:
                // For system mode, default to dark (will be overridden by preferredColorScheme)
                return true
            }
        }

        // MARK: - Background Colors

        static var background: Color {
            isDarkMode
                ? Color(red: 0.04, green: 0.07, blue: 0.05)  // Dark green-black
                : Color(red: 0.97, green: 0.96, blue: 0.94)  // Warm off-white
        }

        static var backgroundLight: Color {
            isDarkMode
                ? Color(red: 0.06, green: 0.09, blue: 0.07)
                : Color(red: 0.94, green: 0.93, blue: 0.91)
        }

        static var cardBackground: Color {
            isDarkMode
                ? Color(red: 0.10, green: 0.14, blue: 0.12)  // Dark card
                : Color(red: 1.0, green: 0.99, blue: 0.97)   // Warm white card
        }

        static var cardBackgroundLight: Color {
            isDarkMode
                ? Color(red: 0.12, green: 0.16, blue: 0.14)
                : Color(red: 0.98, green: 0.97, blue: 0.95)
        }

        // MARK: - Accent Colors (dynamic based on user theme selection)

        static var accent: Color {
            UserPreferences.shared.themeColorOption.accentColor
        }

        static var accentMuted: Color {
            UserPreferences.shared.themeColorOption.accentMuted
        }

        // MARK: - Text Colors

        static var textPrimary: Color {
            isDarkMode
                ? Color.white.opacity(0.95)
                : Color(red: 0.15, green: 0.15, blue: 0.13)  // Dark warm gray
        }

        static var textSecondary: Color {
            isDarkMode
                ? Color.white.opacity(0.65)
                : Color(red: 0.35, green: 0.35, blue: 0.32)  // Medium warm gray
        }

        static var textTertiary: Color {
            isDarkMode
                ? Color.white.opacity(0.45)
                : Color(red: 0.55, green: 0.55, blue: 0.52)  // Light warm gray
        }

        // MARK: - Status Colors

        static var success: Color {
            isDarkMode
                ? Color(red: 0.55, green: 0.75, blue: 0.55)
                : Color(red: 0.30, green: 0.60, blue: 0.35)
        }

        static var warning: Color {
            isDarkMode
                ? Color(red: 0.85, green: 0.70, blue: 0.45)
                : Color(red: 0.80, green: 0.60, blue: 0.20)
        }

        static var error: Color {
            isDarkMode
                ? Color(red: 0.85, green: 0.45, blue: 0.45)
                : Color(red: 0.75, green: 0.30, blue: 0.30)
        }

        // MARK: - Category Colors

        static var focus: Color {
            isDarkMode
                ? Color(red: 0.55, green: 0.70, blue: 0.75)
                : Color(red: 0.35, green: 0.55, blue: 0.65)
        }

        static var deep: Color {
            isDarkMode
                ? Color(red: 0.60, green: 0.65, blue: 0.55)
                : Color(red: 0.45, green: 0.50, blue: 0.40)
        }

        static var social: Color {
            isDarkMode
                ? Color(red: 0.75, green: 0.65, blue: 0.55)
                : Color(red: 0.65, green: 0.50, blue: 0.40)
        }

        // MARK: - Energy Gradient Colors (for heatmap)

        static var energyStill: Color {
            isDarkMode
                ? Color(red: 0.25, green: 0.28, blue: 0.26)
                : Color(red: 0.90, green: 0.89, blue: 0.87)
        }

        static var energyEase: Color {
            isDarkMode
                ? Color(red: 0.45, green: 0.55, blue: 0.45)
                : Color(red: 0.75, green: 0.82, blue: 0.75)
        }

        static var energyFlow: Color {
            isDarkMode
                ? Color(red: 0.55, green: 0.65, blue: 0.60)
                : Color(red: 0.60, green: 0.72, blue: 0.65)
        }

        static var energyPower: Color {
            isDarkMode
                ? Color(red: 0.60, green: 0.70, blue: 0.65)
                : Color(red: 0.50, green: 0.65, blue: 0.55)
        }

        static var energyPeak: Color {
            isDarkMode
                ? Color(red: 0.55, green: 0.70, blue: 0.75)
                : Color(red: 0.40, green: 0.58, blue: 0.50)
        }

        // MARK: - Badge Colors (Monochromatic)

        /// Primary badge color - subtle, neutral
        static var badge: Color {
            isDarkMode
                ? Color.white.opacity(0.55)
                : Color.black.opacity(0.50)
        }

        /// Badge background fill
        static var badgeBackground: Color {
            isDarkMode
                ? Color.white.opacity(0.08)
                : Color.black.opacity(0.05)
        }

        /// Badge border
        static var badgeBorder: Color {
            isDarkMode
                ? Color.white.opacity(0.12)
                : Color.black.opacity(0.08)
        }

        // MARK: - Divider/Border Colors

        static var divider: Color {
            isDarkMode
                ? Color.white.opacity(0.1)
                : Color.black.opacity(0.08)
        }

        static var border: Color {
            isDarkMode
                ? Color.white.opacity(0.15)
                : Color.black.opacity(0.1)
        }

        // MARK: - Archetype Colors

        static var archetypeLab: Color {
            isDarkMode
                ? Color(red: 0.45, green: 0.60, blue: 0.85)  // Blue
                : Color(red: 0.30, green: 0.50, blue: 0.80)
        }

        static var archetypeHunt: Color {
            isDarkMode
                ? Color(red: 0.90, green: 0.60, blue: 0.35)  // Orange
                : Color(red: 0.85, green: 0.50, blue: 0.25)
        }

        static var archetypeSpiral: Color {
            isDarkMode
                ? Color(red: 0.70, green: 0.50, blue: 0.80)  // Purple
                : Color(red: 0.60, green: 0.40, blue: 0.75)
        }

        static var archetypeBuild: Color {
            isDarkMode
                ? Color(red: 0.50, green: 0.75, blue: 0.50)  // Green
                : Color(red: 0.35, green: 0.65, blue: 0.40)
        }

        /// Get color for an archetype string
        static func archetypeColor(for archetype: String?) -> Color {
            guard let archetype = archetype?.lowercased() else { return accent }
            switch archetype {
            case "lab": return archetypeLab
            case "hunt": return archetypeHunt
            case "spiral": return archetypeSpiral
            case "build": return archetypeBuild
            default: return accent
            }
        }
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
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 24
        static let card: CGFloat = 34  // For flow cards - very rounded
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
