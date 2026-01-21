import SwiftUI
import SwiftData

struct ContentView: View {
    private var prefs = UserPreferences.shared

    var body: some View {
        TabView {
            TodayFlowView()
                .tabItem {
                    Label("Flow", systemImage: "drop.fill")
                }

            UnifiedInputView()
                .tabItem {
                    Label("Ask", systemImage: "bubble.left.and.bubble.right")
                }

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
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

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, ProjectPhase.self, PlannedSession.self, StoneEvent.self, TouchLog.self, FocusSession.self], inMemory: true)
}
