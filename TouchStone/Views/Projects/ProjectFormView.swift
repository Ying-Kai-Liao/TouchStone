import SwiftUI
import SwiftData

enum ProjectFormMode {
    case create
    case edit(Project)
}

struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: ProjectFormMode
    let onSave: (Project) -> Void

    @State private var title: String = ""
    @State private var currentPhase: String = ""
    @State private var hasSoftDeadline: Bool = false
    @State private var softDeadline: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingProject: Project? {
        if case .edit(let project) = mode { return project }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project name", text: $title)
                }

                Section {
                    TextField("e.g., Discovery, Research, Building", text: $currentPhase)
                } header: {
                    Text("Phase (optional)")
                }

                Section {
                    Toggle("Soft deadline", isOn: $hasSoftDeadline)

                    if hasSoftDeadline {
                        DatePicker(
                            "Target date",
                            selection: $softDeadline,
                            displayedComponents: .date
                        )
                    }
                } footer: {
                    Text("A soft deadline is a gentle reminder, not a hard constraint.")
                }
            }
            .navigationTitle(isEditing ? "Edit Project" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProject()
                    }
                    .disabled(title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let project = existingProject {
                    title = project.title
                    currentPhase = project.currentPhase ?? ""
                    hasSoftDeadline = project.softDeadline != nil
                    softDeadline = project.softDeadline ?? Date().addingTimeInterval(30 * 24 * 60 * 60)
                }
            }
        }
    }

    private func saveProject() {
        if let project = existingProject {
            project.title = title
            project.currentPhase = currentPhase.isEmpty ? nil : currentPhase
            project.softDeadline = hasSoftDeadline ? softDeadline : nil
        } else {
            let project = Project(
                title: title,
                currentPhase: currentPhase.isEmpty ? nil : currentPhase,
                softDeadline: hasSoftDeadline ? softDeadline : nil
            )
            onSave(project)
        }
        dismiss()
    }
}

#Preview {
    ProjectFormView(mode: .create) { _ in }
}
