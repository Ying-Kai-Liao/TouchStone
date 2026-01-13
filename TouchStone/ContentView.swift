import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TodayFlowView()
                .tabItem {
                    Label("Flow", systemImage: "drop.fill")
                }

            ProjectsListView()
                .tabItem {
                    Label("Plan", systemImage: "square.grid.2x2")
                }

            CalendarView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, ProjectPhase.self, PlannedSession.self, StoneEvent.self, TouchLog.self, FocusSession.self], inMemory: true)
}
