import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Chat-based interface for AI-assisted plan refinement.
/// Allows users to provide context (text and documents) and request plan modifications.
struct PlanRefinementChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var prefs: UserPreferences { UserPreferences.shared }

    @Bindable var project: Project

    @State private var step: RefinementStep = .context
    @State private var userRequest = ""
    @State private var showDocumentPicker = false
    @State private var pendingDocuments: [PendingDocument] = []
    @State private var refinementResult: PlanRefinementEngine.RefinementResult?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private let refinementEngine = PlanRefinementEngine()
    private let textExtractor = DocumentTextExtractor()

    // MARK: - Refinement Steps

    enum RefinementStep {
        case context           // Show current plan state, gather user input
        case processing        // AI generating refinement
        case review            // User reviews proposed changes
        case applying          // Applying changes to model
    }

    // MARK: - Pending Document

    struct PendingDocument: Identifiable {
        let id = UUID()
        let url: URL
        let filename: String
        var extractedText: String?
        var error: String?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case .context:
                        contextInputSection
                    case .processing:
                        loadingSection("Refining your plan...")
                    case .review:
                        refinementReviewSection
                    case .applying:
                        loadingSection("Applying changes...")
                    }
                }
                .padding()
            }
            .navigationTitle("Refine Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.pdf, .plainText, .rtf],
                allowsMultipleSelection: true
            ) { result in
                handleDocumentSelection(result)
            }
        }
    }

    // MARK: - Context Input Section

    private var contextInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Current progress card
            currentProgressCard

            // Assistant message
            chatBubble(
                "What would you like to change about your plan? You can describe adjustments or attach documents for additional context.",
                isAssistant: true
            )

            // User request input
            TextField("e.g., I need to spend more time on research...", text: $userRequest, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(3...6)

            // Document attachments
            if !pendingDocuments.isEmpty {
                documentAttachmentsSection
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    showDocumentPicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Add Document")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    Task { await generateRefinement() }
                } label: {
                    HStack {
                        Text("Refine Plan")
                        Image(systemName: "sparkles")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(userRequest.isEmpty ? Color.gray : prefs.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(userRequest.isEmpty || isProcessing)
            }
        }
    }

    // MARK: - Current Progress Card

    private var currentProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(project.title)
                    .font(.headline)

                if let archetype = project.archetype {
                    Text(archetype.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(prefs.accentColor.opacity(0.15))
                        .foregroundStyle(prefs.accentColor)
                        .clipShape(Capsule())
                }
            }

            // Progress bar
            ProgressView(value: project.progress)
                .tint(prefs.accentColor)

            Text(project.progressString)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Logged work info
            let loggedHours = project.completedHours
            if loggedHours > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.green)
                    Text("\(loggedHours)h already logged")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Document Attachments Section

    private var documentAttachmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attached Documents")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(pendingDocuments) { doc in
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(prefs.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.filename)
                            .font(.subheadline)
                            .lineLimit(1)

                        if doc.extractedText != nil {
                            Text("Ready")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if let error = doc.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("Processing...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        pendingDocuments.removeAll { $0.id == doc.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Loading Section

    private func loadingSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Refinement Review Section

    private var refinementReviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AI reasoning
            if let result = refinementResult {
                chatBubble(result.reasoning, isAssistant: true)

                // Proposed changes
                Text("Proposed Changes")
                    .font(.headline)

                ForEach(Array(result.phases.enumerated()), id: \.offset) { _, phasePlan in
                    proposedPhaseCard(phasePlan)
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        step = .context
                        refinementResult = nil
                    } label: {
                        Text("Revise Request")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        Task { await applyRefinement() }
                    } label: {
                        HStack {
                            Text("Apply Changes")
                            Image(systemName: "checkmark")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Proposed Phase Card

    private func proposedPhaseCard(_ phasePlan: PlanRefinementEngine.PhasePlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(phasePlan.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(phasePlan.estimatedMinutes / 60)h budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let mentalRule = phasePlan.mentalRule, !mentalRule.isEmpty {
                Text("\"\(mentalRule)\"")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(prefs.accentColor)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ text: String, isAssistant: Bool) -> some View {
        HStack {
            if !isAssistant { Spacer() }

            Text(text)
                .font(.subheadline)
                .padding(12)
                .background(isAssistant ? Color(.secondarySystemGroupedBackground) : prefs.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if isAssistant { Spacer() }
        }
    }

    // MARK: - Actions

    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let filename = url.lastPathComponent
                var doc = PendingDocument(url: url, filename: filename)
                pendingDocuments.append(doc)

                // Extract text asynchronously
                Task {
                    do {
                        let text = try await textExtractor.extractText(from: url)
                        if let index = pendingDocuments.firstIndex(where: { $0.url == url }) {
                            pendingDocuments[index].extractedText = text
                        }
                    } catch {
                        if let index = pendingDocuments.firstIndex(where: { $0.url == url }) {
                            pendingDocuments[index].error = error.localizedDescription
                        }
                    }
                }
            }
        case .failure(let error):
            errorMessage = "Failed to select documents: \(error.localizedDescription)"
        }
    }

    private func generateRefinement() async {
        isProcessing = true
        errorMessage = nil
        step = .processing

        // Collect document texts
        let documentTexts = pendingDocuments.compactMap { $0.extractedText }

        let context = PlanRefinementEngine.RefinementContext(
            project: project,
            userRequest: userRequest,
            additionalDocumentTexts: documentTexts
        )

        do {
            let result = try await refinementEngine.refinePlan(context: context)
            refinementResult = result
            step = .review
        } catch {
            errorMessage = "Failed to refine plan: \(error.localizedDescription)"
            step = .context
        }

        isProcessing = false
    }

    private func applyRefinement() async {
        guard let result = refinementResult else { return }

        step = .applying
        isProcessing = true

        // Apply the refinement to the project with proper SwiftData management
        applyRefinementToProject(result: result)

        // Save any pending documents to the project
        for doc in pendingDocuments {
            if let text = doc.extractedText {
                let projectDoc = ProjectDocument(
                    filename: doc.filename,
                    fileType: doc.url.pathExtension,
                    bookmarkData: ProjectDocument.createBookmark(from: doc.url),
                    extractedText: text
                )
                projectDoc.project = project
                modelContext.insert(projectDoc)
            }
        }

        // Update planning notes if user provided context
        if !userRequest.isEmpty {
            let existingNotes = project.planningNotes ?? ""
            let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
            project.planningNotes = existingNotes + "\n[\(timestamp)] \(userRequest)"
        }

        isProcessing = false
        dismiss()
    }

    /// Apply refinement result to the project with proper SwiftData management
    private func applyRefinementToProject(result: PlanRefinementEngine.RefinementResult) {
        for existingPhase in project.sortedPhases {
            // Find the corresponding phase plan from the result
            guard let phasePlan = result.phases.first(where: { $0.name == existingPhase.title }) else {
                continue
            }

            // Update phase time budget from the refinement result
            existingPhase.estimatedMinutes = phasePlan.estimatedMinutes

            // Update mental rule if changed
            if let newRule = phasePlan.mentalRule, !newRule.isEmpty {
                existingPhase.mentalRule = newRule
            }
        }

        // Update project's last modified timestamp
        project.lastPlanModifiedAt = Date()
    }
}

// MARK: - Preview

#Preview {
    PlanRefinementChatView(
        project: Project(title: "ML Research Paper", archetype: .lab, totalPlannedMinutes: 2400)
    )
    .modelContainer(for: [Project.self, ProjectPhase.self, Milestone.self, ProjectDocument.self], inMemory: true)
}
