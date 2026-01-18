import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: $selectedTab) {
                TodayFlowView()
                    .tag(0)

                CalendarView()
                    .tag(1)

                ProjectsListView()
                    .tag(2)

                MeView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String)] = [
        ("drop.fill", "FLOW"),
        ("calendar", "HORIZON"),
        ("square.grid.2x2", "PLAN"),
        ("person.fill", "ME")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 20))

                        Text(tabs[index].label)
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.5)
                    }
                    .foregroundStyle(selectedTab == index ?
                        DesignSystem.Colors.accent :
                        DesignSystem.Colors.textTertiary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(
            DesignSystem.Colors.backgroundLight
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, ProjectPhase.self, PlannedSession.self, StoneEvent.self, TouchLog.self, FocusSession.self], inMemory: true)
}
