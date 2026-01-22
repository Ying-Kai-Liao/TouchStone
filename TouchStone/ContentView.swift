import SwiftUI
import SwiftData

struct ContentView: View {
    private var prefs = UserPreferences.shared

    var body: some View {
        ZStack {
            // Noisy gradient background
            NoisyGradientBackground()

            TabView {
                TodayFlowView()
                    .tabItem {
                        Label("Flow", systemImage: "drop.fill")
                    }

                CalendarView()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }

                UnifiedInputView()
                    .tabItem {
                        Label("Ask", systemImage: "sparkles")
                    }

                ProjectsListView()
                    .tabItem {
                        Label("Plan", systemImage: "square.grid.2x2")
                    }

                MeView()
                    .tabItem {
                        Label("Me", systemImage: "person")
                    }
            }
            .tint(prefs.accentColor)
        }
    }
}
#Preview {
    ContentView()
        .modelContainer(for: [Project.self, ProjectPhase.self, Milestone.self, StoneEvent.self, TouchLog.self, FocusSession.self], inMemory: true)
}
