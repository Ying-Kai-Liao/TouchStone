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

    private var weeklyGoal: Int {
        prefs.dailyProductiveHours * 5
    }

    private var weeklyProgressValue: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(1.0, Double(thisWeekHours) / Double(weeklyGoal))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Settings button
                    HStack {
                        Spacer()
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(DesignSystem.Colors.cardBackground)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    // Greeting
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text(greetingText)
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text("Keep touching your work")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    // Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                        MeStatCard(
                            value: "\(todayHours)",
                            unit: "HRS",
                            label: "TODAY",
                            icon: "sun.max.fill",
                            iconColor: DesignSystem.Colors.warning
                        )

                        MeStatCard(
                            value: "\(thisWeekHours)",
                            unit: "HRS",
                            label: "THIS WEEK",
                            icon: "calendar",
                            iconColor: DesignSystem.Colors.focus
                        )

                        MeStatCard(
                            value: "\(currentStreak)",
                            unit: "DAYS",
                            label: "STREAK",
                            icon: "flame.fill",
                            iconColor: .orange
                        )

                        MeStatCard(
                            value: "\(activeProjects)",
                            unit: "ACTIVE",
                            label: "PROJECTS",
                            icon: "folder.fill",
                            iconColor: .purple
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    // Weekly Goal
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Text("WEEKLY GOAL")
                                .sectionHeader()
                            Spacer()
                            Text("\(Int(weeklyProgressValue * 100))%")
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("\(thisWeekHours) / \(weeklyGoal) hours")
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DesignSystem.Colors.cardBackgroundLight)
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DesignSystem.Colors.accent)
                                        .frame(width: geometry.size.width * weeklyProgressValue, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .cardStyle()
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }

                    // Journey Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("JOURNEY")
                            .sectionHeader()
                            .padding(.horizontal, DesignSystem.Spacing.lg)

                        VStack(spacing: 0) {
                            JourneyRow(icon: "clock", title: "Total Time", value: "\(totalHours) hours")
                            JourneyRow(icon: "checkmark.circle", title: "Completed", value: "\(completedProjects) projects")
                            JourneyRow(icon: "hand.tap", title: "Total Touches", value: "\(allTouchLogs.count)", showDivider: false)
                        }
                        .cardStyle()
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarHidden(true)
        }
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
}

// MARK: - Stat Card

private struct MeStatCard: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(DesignSystem.Typography.statMedium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Text(unit)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Journey Row

private struct JourneyRow: View {
    let icon: String
    let title: String
    let value: String
    var showDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(DesignSystem.Colors.cardBackgroundLight)
                    .clipShape(Circle())

                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                Text(value)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)

            if showDivider {
                Divider()
                    .background(DesignSystem.Colors.cardBackgroundLight)
                    .padding(.leading, 60)
            }
        }
    }
}

#Preview {
    MeView()
        .modelContainer(for: [Project.self, TouchLog.self], inMemory: true)
}
