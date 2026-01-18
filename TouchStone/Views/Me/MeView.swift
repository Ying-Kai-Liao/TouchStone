import SwiftUI
import SwiftData

struct MeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allProjects: [Project]
    @Query private var allTouchLogs: [TouchLog]

    private let prefs = UserPreferences.shared
    private let calendar = Calendar.current

    // MARK: - Computed Stats

    private var activeProjects: Int {
        allProjects.filter { $0.isActive }.count
    }

    private var totalHours: Int {
        allTouchLogs.reduce(0) { $0 + $1.durationMinutes } / 60
    }

    private var thisWeekHours: Int {
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return allTouchLogs
            .filter { $0.timestamp >= weekStart }
            .reduce(0) { $0 + $1.durationMinutes } / 60
    }

    private var todayHours: Int {
        let today = calendar.startOfDay(for: Date())
        return allTouchLogs
            .filter { calendar.startOfDay(for: $0.timestamp) == today }
            .reduce(0) { $0 + $1.durationMinutes } / 60
    }

    private var currentStreak: Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if there's a touch today, if not start from yesterday
        let todayTouches = allTouchLogs.filter { calendar.startOfDay(for: $0.timestamp) == checkDate }
        if todayTouches.isEmpty {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let dayTouches = allTouchLogs.filter { calendar.startOfDay(for: $0.timestamp) == checkDate }
            if dayTouches.isEmpty { break }
            streak += 1
            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
        }

        return streak
    }

    private var completedProjects: Int {
        allProjects.filter { !$0.isActive && $0.totalTouchCount > 0 }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom header
                    headerView
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.top, DesignSystem.Spacing.sm)

                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.xl) {
                            // Header with greeting
                            headerSection

                            // Main stats grid
                            statsGrid

                            // Weekly overview
                            weeklyProgress

                            // Quick insights
                            insightsSection

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.md)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center) {
            Text("Me")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text(greetingText)
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Keep touching your work")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DesignSystem.Spacing.lg)
    }

    private var greetingText: String {
        let hour = calendar.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
            StatCard(
                title: "Today",
                value: "\(todayHours)",
                unit: "hrs",
                icon: "sun.max",
                color: DesignSystem.Colors.accent
            )

            StatCard(
                title: "This Week",
                value: "\(thisWeekHours)",
                unit: "hrs",
                icon: "calendar",
                color: DesignSystem.Colors.focus
            )

            StatCard(
                title: "Streak",
                value: "\(currentStreak)",
                unit: "days",
                icon: "flame",
                color: DesignSystem.Colors.warning
            )

            StatCard(
                title: "Active",
                value: "\(activeProjects)",
                unit: "projects",
                icon: "folder",
                color: DesignSystem.Colors.social
            )
        }
    }

    // MARK: - Weekly Progress

    private var weeklyProgress: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("WEEKLY GOAL")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.5)

            let weeklyGoal = prefs.dailyProductiveHours * 5 // 5 working days
            let progress = min(1.0, Double(thisWeekHours) / Double(weeklyGoal))

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("\(thisWeekHours) / \(weeklyGoal) hours")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                            .fill(DesignSystem.Colors.textTertiary.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs)
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("JOURNEY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.5)

            VStack(spacing: 0) {
                InsightRow(icon: "clock", title: "Total Time", value: "\(totalHours) hours")
                Divider()
                    .background(DesignSystem.Colors.textTertiary.opacity(0.2))
                    .padding(.leading, 44)
                InsightRow(icon: "checkmark.circle", title: "Completed", value: "\(completedProjects) projects")
                Divider()
                    .background(DesignSystem.Colors.textTertiary.opacity(0.2))
                    .padding(.leading, 44)
                InsightRow(icon: "hand.tap", title: "Total Touches", value: "\(allTouchLogs.count)")
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
                    Text(value)
                        .font(DesignSystem.Typography.statMedium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(unit)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Insight Row

private struct InsightRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .frame(width: 24)

            Text(title)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md + 2)
    }
}

#Preview {
    MeView()
        .modelContainer(for: [Project.self, TouchLog.self], inMemory: true)
}
