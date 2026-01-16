import SwiftUI
import SwiftData

/// FocusModeView - Redesigned focus experience
/// Shows: Project name + abstract visual + intention
/// Elegant expandable details via card tap
struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let project: Project
    let onDismiss: () -> Void

    @State private var note: String = ""
    @State private var showDetails = false
    @State private var showMenu = false
    @State private var hasStarted = false

    var activePhase: ProjectPhase? {
        project.activePhase
    }

    var currentSession: PlannedSession? {
        project.nextPlannedSession
    }

    // Get intention text from session goal or phase
    var intentionText: String {
        if let session = currentSession, let goal = session.goal {
            return goal
        } else if let session = currentSession {
            return session.title
        } else if let phase = activePhase {
            return phase.title
        } else if let phase = project.currentPhase {
            return phase
        }
        return "Deep work"
    }

    // Get category label (WORK, CREATIVE, etc.)
    var categoryLabel: String {
        guard let archetype = project.archetype else {
            return "WORK"
        }
        switch archetype {
        case .lab: return "RESEARCH"
        case .hunt: return "ADMIN"
        case .spiral: return "LEARNING"
        case .build: return "BUILD"
        }
    }

    // MARK: - Colors

    private let darkGreen = Color(red: 0.08, green: 0.12, blue: 0.10)
    private let accentGreen = Color(red: 0.20, green: 0.85, blue: 0.55)
    private let cardBackground = Color(red: 0.12, green: 0.18, blue: 0.15)

    var body: some View {
        ZStack {
            // Dark green gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.10, blue: 0.08),
                    Color(red: 0.08, green: 0.14, blue: 0.11),
                    Color(red: 0.06, green: 0.11, blue: 0.09)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 8)

                Spacer()

                // Main content card
                mainCard
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showDetails.toggle()
                        }
                    }

                Spacer()

                // Intention pill
                intentionPill
                    .padding(.bottom, 24)

                // Action button
                actionButton
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDetails) {
            detailsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(cardBackground)
        }
        .confirmationDialog("Options", isPresented: $showMenu) {
            Button("View Details") {
                showDetails = true
            }
            Button("Add Note") {
                showDetails = true
            }
            Button("Don't Log", role: .destructive) {
                dismissWithoutLogging()
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
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text("NOW")
                .font(.system(size: 14, weight: .semibold))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Button {
                showMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Main Card

    private var mainCard: some View {
        VStack(spacing: 0) {
            // Image container with badge
            ZStack(alignment: .topTrailing) {
                // Abstract art placeholder
                AbstractArtView()
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(16)

                // Category badge
                Text(categoryLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(accentGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                    )
                    .padding(.top, 28)
                    .padding(.trailing, 28)
            }

            // Project title
            Text(project.title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 24)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    // MARK: - Intention Pill

    private var intentionPill: some View {
        VStack(spacing: 6) {
            Text("INTENTION")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))

            Text(intentionText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
        .padding(.horizontal, 40)
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
                    .font(.system(size: 18, weight: .semibold))
                Text(hasStarted ? "Done" : "Begin")
                    .font(.system(size: 19, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(accentGreen)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Details Sheet

    private var detailsSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("Details")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.top, 8)

                // Phase section
                if let phase = activePhase {
                    detailSection(
                        icon: "layers.fill",
                        title: "Current Phase",
                        content: phase.title,
                        subtitle: phase.mentalRule
                    )
                } else if let phase = project.currentPhase {
                    detailSection(
                        icon: "layers.fill",
                        title: "Current Phase",
                        content: phase,
                        subtitle: nil
                    )
                }

                // Session goal section
                if let session = currentSession {
                    detailSection(
                        icon: "target",
                        title: "Session Goal",
                        content: session.title,
                        subtitle: session.goal
                    )
                }

                // Mental rule section
                if let phase = activePhase, let rule = phase.mentalRule {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 14))
                                .foregroundStyle(accentGreen)
                            Text("Mental Rule")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Text("\"\(rule)\"")
                            .font(.system(size: 17))
                            .italic()
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(accentGreen.opacity(0.1))
                            )
                    }
                }

                // Note section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 14))
                            .foregroundStyle(accentGreen)
                        Text("Session Note")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    TextField("Add a note...", text: $note, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                        .lineLimit(3...6)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }

    private func detailSection(icon: String, title: String, content: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(accentGreen)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(content)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
        }
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

    private func dismissWithoutLogging() {
        onDismiss()
    }
}

// MARK: - Abstract Art View (Placeholder)

/// Generates an abstract swirly gradient art similar to the design reference
/// This can be replaced with an actual image later
struct AbstractArtView: View {
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.65, green: 0.72, blue: 0.60),
                    Color(red: 0.45, green: 0.58, blue: 0.55),
                    Color(red: 0.35, green: 0.50, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Swirl effect using radial gradients
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.80, green: 0.85, blue: 0.75).opacity(0.8),
                            Color(red: 0.55, green: 0.65, blue: 0.60).opacity(0.4),
                            Color.clear
                        ],
                        center: .init(x: 0.3, y: 0.3),
                        startRadius: 10,
                        endRadius: 200
                    )
                )
                .scaleEffect(x: 1.5, y: 1.2)
                .offset(x: -50, y: -30)

            // Additional swirl layer
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.40, green: 0.55, blue: 0.60).opacity(0.6),
                            Color(red: 0.30, green: 0.45, blue: 0.50).opacity(0.3),
                            Color.clear
                        ],
                        center: .init(x: 0.7, y: 0.6),
                        startRadius: 20,
                        endRadius: 180
                    )
                )
                .scaleEffect(x: 1.3, y: 1.0)
                .offset(x: 40, y: 50)

            // Light arc effect
            Arc(startAngle: .degrees(180), endAngle: .degrees(300), clockwise: false)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.88, blue: 0.80).opacity(0.5),
                            Color(red: 0.70, green: 0.78, blue: 0.72).opacity(0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 40, lineCap: .round)
                )
                .frame(width: 300, height: 300)
                .offset(x: -30, y: -20)
                .blur(radius: 20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
        return path
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
