import SwiftUI
import SwiftData

/// FocusModeView is an optional, minimal focus experience.
/// Per STATE_MACHINE.md:
/// - Shows: Project name + phase + short goal line
/// - Soft time container (~1h) without strict countdown
/// - Can exit anytime (leaving early = finishing)
///
/// Phase goal is collapsible, session goal is very subtle (only visible when wanted)
struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let project: Project
    let onDismiss: () -> Void

    @State private var note: String = ""
    @State private var showPhaseDetails = false
    @State private var showSessionGoal = false
    @State private var showMenu = false
    @State private var hasStarted = false
    @State private var remainingMinutes: Int = 55

    var activePhase: ProjectPhase? {
        project.activePhase
    }

    var currentSession: PlannedSession? {
        project.nextPlannedSession
    }

    // MARK: - Colors

    private let accentGreen = Color(red: 0.55, green: 0.75, blue: 0.60)
    private let softBackground = Color(red: 0.98, green: 0.97, blue: 0.95)
    private let cardBackground = Color.white

    var body: some View {
        ZStack {
            // Soft gradient background
            LinearGradient(
                colors: [softBackground, softBackground.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                Spacer()

                // Main content card
                mainCard

                Spacer()

                // Action button
                actionButton

                // Progress indicator
                progressIndicator
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
        }
        .confirmationDialog("Options", isPresented: $showMenu) {
            if let session = currentSession {
                Button("View Session Goal") {
                    showSessionGoal.toggle()
                }
            }
            if let phase = activePhase, phase.mentalRule != nil {
                Button("View Phase Details") {
                    showPhaseDetails.toggle()
                }
            }
            Button("Add Note") {
                // Focus on note - could scroll to note section
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button {
                finishFocus()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("NOW")
                .font(.system(size: 13, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                showMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Main Card

    private var mainCard: some View {
        VStack(spacing: 20) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(accentGreen.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(accentGreen.opacity(0.6))
            }
            .padding(.top, 32)

            // Project title
            Text(project.title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)

            // Phase subtitle (if available)
            if let phase = activePhase {
                phaseLabel(phase: phase)
            } else if let phase = project.currentPhase {
                Text(phase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Time remaining badge
            timeRemainingBadge
                .padding(.top, 4)

            // Expanded phase details
            if showPhaseDetails, let phase = activePhase, let rule = phase.mentalRule {
                phaseDetailsView(rule: rule)
                    .padding(.top, 8)
            }

            // Expanded session goal
            if showSessionGoal, let session = currentSession {
                sessionGoalView(session: session)
                    .padding(.top, 8)
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 20, x: 0, y: 4)
        .padding(.horizontal, 24)
    }

    // MARK: - Phase Label

    private func phaseLabel(phase: ProjectPhase) -> some View {
        Button {
            if phase.mentalRule != nil {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showPhaseDetails.toggle()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(phase.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if phase.mentalRule != nil {
                    Image(systemName: showPhaseDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Remaining Badge

    private var timeRemainingBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 13))
            Text("\(remainingMinutes) min remaining")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    // MARK: - Phase Details View

    private func phaseDetailsView(rule: String) -> some View {
        VStack(spacing: 8) {
            Text("Mental Rule")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)

            Text("\"\(rule)\"")
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Session Goal View

    private func sessionGoalView(session: PlannedSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Goal")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)

            Text(session.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            if let goal = session.goal {
                Text(goal)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button {
            if hasStarted {
                finishFocus()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    hasStarted = true
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: hasStarted ? "checkmark" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(hasStarted ? "Done" : "Begin")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(accentGreen)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 48)
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 6, height: 6)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray5))
                .frame(width: 120, height: 4)
        }
        .opacity(0.6)
    }

    // MARK: - Actions

    private func finishFocus() {
        let touch = TouchLog(
            durationMinutes: 60,
            note: note.isEmpty ? nil : note,
            project: project
        )
        modelContext.insert(touch)
        onDismiss()
    }
}

#Preview("Simple Project") {
    FocusModeView(
        project: Project(title: "Draft Quarterly Report", currentPhase: "Writing"),
        onDismiss: {}
    )
}

#Preview("Strategic Project") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, ProjectPhase.self, PlannedSession.self, configurations: config)

    let project = Project(title: "Research Paper", archetype: .lab)
    container.mainContext.insert(project)

    let phase = ProjectPhase(
        title: "Exploration",
        phaseType: .divergent,
        mentalRule: "Explore widely, no conclusions yet",
        sequenceOrder: 0
    )
    phase.project = project
    container.mainContext.insert(phase)

    let session = PlannedSession(
        title: "Literature Safari",
        goal: "Find and bookmark 15 related papers on ML optimization",
        estimatedMinutes: 90,
        sequenceOrder: 0
    )
    session.phase = phase
    container.mainContext.insert(session)

    project.phases = [phase]
    phase.sessions = [session]

    return FocusModeView(project: project, onDismiss: {})
        .modelContainer(container)
}
