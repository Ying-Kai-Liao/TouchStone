import SwiftUI
import SwiftData

struct NewProjectChoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showQuickProject = false
    @State private var showAIChat = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("New Project")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("How would you like to create your project?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(spacing: 16) {
                    // Quick Project
                    Button {
                        showQuickProject = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "bolt.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .frame(width: 44, height: 44)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quick Project")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Just a title, start working right away")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // AI-Assisted Project (new chat interface)
                    Button {
                        showAIChat = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(UserPreferences.shared.accentColor)
                                .frame(width: 44, height: 44)
                                .background(UserPreferences.shared.accentColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Assistant")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Chat to create projects, events, and more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showQuickProject) {
                QuickProjectFormView { project in
                    modelContext.insert(project)
                    dismiss()
                }
            }
            .sheet(isPresented: $showAIChat) {
                UnifiedInputView()
                    .onDisappear {
                        dismiss()
                    }
            }
        }
    }
}

// MARK: - Quick Project Form

struct QuickProjectFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var currentPhase = ""
    @State private var hasDeadline = false
    @State private var deadlineDate = Date().addingTimeInterval(7 * 24 * 60 * 60)

    let onSave: (Project) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project title", text: $title)
                } header: {
                    Text("Title")
                }

                Section {
                    TextField("e.g., Research, Drafting, Review", text: $currentPhase)
                } header: {
                    Text("Current Phase (Optional)")
                } footer: {
                    Text("A simple label to remind you where you are")
                }

                Section {
                    Toggle("Deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Date", selection: $deadlineDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("Set a deadline to track pressure and feasibility")
                }
            }
            .navigationTitle("Quick Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let project = Project(
                            title: title,
                            currentPhase: currentPhase.isEmpty ? nil : currentPhase,
                            deadline: hasDeadline ? deadlineDate : nil
                        )
                        onSave(project)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NewProjectChoiceView()
        .modelContainer(for: Project.self, inMemory: true)
}
