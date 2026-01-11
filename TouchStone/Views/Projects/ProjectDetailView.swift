import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project

    @State private var showingEditSheet = false
    @State private var showingLogSheet = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if let phase = project.currentPhase {
                        Label(phase, systemImage: "flag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let deadline = project.softDeadline {
                        Label(deadlineText(deadline), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(deadlineColor)
                    }

                    HStack {
                        Label("\(project.totalTouchCount) touches total", systemImage: "hand.tap")
                        Spacer()
                        if project.touchCountToday > 0 {
                            Text("Today: \(project.touchCountToday)")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if project.totalMinutesInvested > 0 {
                        Label("~\(formattedTime(project.totalMinutesInvested)) invested", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    logTouch()
                } label: {
                    Label("Log Touch Now", systemImage: "hand.tap")
                }

                Toggle("Active", isOn: $project.isActive)
            }

            if !project.touchLogs.isEmpty {
                Section("Recent Touches") {
                    ForEach(project.touchLogs.sorted { $0.timestamp > $1.timestamp }.prefix(10)) { touch in
                        TouchLogRow(touchLog: touch)
                    }
                }
            }
        }
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ProjectFormView(mode: .edit(project)) { _ in }
        }
    }

    private var deadlineColor: Color {
        switch project.deadlineStatus {
        case .none, .comfortable: return .secondary
        case .approaching: return .orange
        case .passed: return .red
        }
    }

    private func deadlineText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: date)

        switch project.deadlineStatus {
        case .passed: return "Past target: \(dateStr)"
        case .approaching: return "Target: \(dateStr) (soon)"
        default: return "Target: \(dateStr)"
        }
    }

    private func formattedTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }

    private func logTouch() {
        let touch = TouchLog(project: project)
        modelContext.insert(touch)
    }
}

struct TouchLogRow: View {
    let touchLog: TouchLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(touchLog.formattedDate)
                    .font(.subheadline)
                Spacer()
                Text(touchLog.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let note = touchLog.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: Project(title: "Q4 Strategy", currentPhase: "Discovery"))
    }
    .modelContainer(for: [Project.self, TouchLog.self], inMemory: true)
}
