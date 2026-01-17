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
            ScrollView {
                VStack(spacing: 32) {
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
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(greetingText)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Keep touching your work")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Today",
                value: "\(todayHours)",
                unit: "hrs",
                icon: "sun.max",
                color: prefs.accentColor
            )

            StatCard(
                title: "This Week",
                value: "\(thisWeekHours)",
                unit: "hrs",
                icon: "calendar",
                color: .blue
            )

            StatCard(
                title: "Streak",
                value: "\(currentStreak)",
                unit: "days",
                icon: "flame",
                color: .orange
            )

            StatCard(
                title: "Active",
                value: "\(activeProjects)",
                unit: "projects",
                icon: "folder",
                color: .purple
            )
        }
    }

    // MARK: - Weekly Progress

    private var weeklyProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEEKLY GOAL")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(1)

            let weeklyGoal = prefs.dailyProductiveHours * 5 // 5 working days
            let progress = min(1.0, Double(thisWeekHours) / Double(weeklyGoal))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(thisWeekHours) / \(weeklyGoal) hours")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(prefs.accentColor)
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("JOURNEY")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(1)

            VStack(spacing: 0) {
                InsightRow(icon: "clock", title: "Total Time", value: "\(totalHours) hours")
                Divider().padding(.leading, 44)
                InsightRow(icon: "checkmark.circle", title: "Completed", value: "\(completedProjects) projects")
                Divider().padding(.leading, 44)
                InsightRow(icon: "hand.tap", title: "Total Touches", value: "\(allTouchLogs.count)")
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Insight Row

private struct InsightRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}

#Preview {
    MeView()
        .modelContainer(for: [Project.self, TouchLog.self], inMemory: true)
}
