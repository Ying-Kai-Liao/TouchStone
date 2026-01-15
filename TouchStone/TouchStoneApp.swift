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
            Rule.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Seed default rules on first launch
            let context = ModelContext(container)
            seedDefaultRules(context: context)
            try? context.save()

            return container
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
