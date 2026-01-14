import SwiftUI
import SwiftData

@main
struct TouchStoneApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Project.self,
            ProjectPhase.self,
            PlannedSession.self,
            StoneEvent.self,
            TouchLog.self,
            FocusSession.self,
            ProjectDocument.self,
            DayPlan.self,
            Backlog.self,
            ScheduledSession.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
