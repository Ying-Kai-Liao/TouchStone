import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }

            ProjectsListView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
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
