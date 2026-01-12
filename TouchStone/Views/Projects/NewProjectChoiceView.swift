import SwiftUI
import SwiftData

struct NewProjectChoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showQuickProject = false
    @State private var showStrategicProject = false

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

                    // Strategic Project
                    Button {
                        showStrategicProject = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "brain.head.profile")
                                .font(.title2)
                                .foregroundStyle(Color.purple)
                                .frame(width: 44, height: 44)
                                .background(Color.purple.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Strategic Project")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("AI breaks it into phases and sessions")
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
                    .disabled(!APIKeyManager.shared.hasAPIKey)
                    .opacity(APIKeyManager.shared.hasAPIKey ? 1 : 0.5)

                    if !APIKeyManager.shared.hasAPIKey {
                        Text("Add OpenAI API key in Settings to use AI planning")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            .sheet(isPresented: $showStrategicProject) {
                StrategicPlanningChatView()
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
    @State private var hasSoftDeadline = false
    @State private var softDeadline = Date().addingTimeInterval(7 * 24 * 60 * 60)

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
                    Toggle("Soft Deadline", isOn: $hasSoftDeadline)
                    if hasSoftDeadline {
                        DatePicker("Date", selection: $softDeadline, displayedComponents: .date)
                    }
                } footer: {
                    Text("A gentle reminder, not pressure")
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
                            softDeadline: hasSoftDeadline ? softDeadline : nil
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
