import SwiftUI
import SwiftData

struct ContentView: View {
    private var prefs = UserPreferences.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayFlowView()
                .tabItem {
                    Label("Flow", systemImage: "drop.fill")
                }
                .tag(0)

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(1)

            ProjectsListView()
                .tabItem {
                    Label("Plan", systemImage: "square.grid.2x2")
                }
                .tag(2)

            MeView()
                .tabItem {
                    Label("Me", systemImage: "person")
                }
                .tag(3)
        }
        .tint(prefs.accentColor)
        .onChange(of: selectedTab) {
            HapticService.tabSelect()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, ProjectPhase.self, PlannedSession.self, StoneEvent.self, TouchLog.self, FocusSession.self], inMemory: true)
}
