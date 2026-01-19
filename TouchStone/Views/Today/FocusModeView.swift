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

    var body: some View {
        ZStack {
            // Background
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, DesignSystem.Spacing.sm)

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
                    .padding(.bottom, DesignSystem.Spacing.xl)

                // Action button
                actionButton
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showDetails) {
            detailsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(DesignSystem.Colors.cardBackground)
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
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.cardBackground)
                    )
            }

            Spacer()

            Text("NOW")
                .font(.system(size: 14, weight: .semibold))
                .tracking(3)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            Button {
                showMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.cardBackground)
                    )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: - Main Card

    private var mainCard: some View {
        VStack(spacing: 0) {
            // Image container with badge
            ZStack(alignment: .topTrailing) {
                // Abstract art placeholder
                AbstractArtView()
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous))
                    .padding(DesignSystem.Spacing.lg)

                // Category badge
                Text(categoryLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.background.opacity(0.8))
                    )
                    .padding(.top, 28)
                    .padding(.trailing, 28)
            }

            // Project title
            Text(project.title)
                .font(DesignSystem.Typography.largeTitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge, style: .continuous)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .shadow(color: DesignSystem.Colors.background.opacity(0.5), radius: 20, y: 10)
    }

    // MARK: - Intention Pill

    private var intentionPill: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("INTENTION")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text(intentionText)
                .font(DesignSystem.Typography.callout)
                .fontWeight(.medium)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .padding(.vertical, DesignSystem.Spacing.md + 2)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .strokeBorder(DesignSystem.Colors.textTertiary.opacity(0.15), lineWidth: 1)
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
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: hasStarted ? "checkmark" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(hasStarted ? "Done" : "Begin")
                    .font(.system(size: 19, weight: .semibold))
            }
            .foregroundStyle(DesignSystem.Colors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xl - 4)
            .background(DesignSystem.Colors.accent)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Details Sheet

    private var detailsSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                // Header
                HStack {
                    Text("Details")
                        .font(DesignSystem.Typography.title)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                }
                .padding(.top, DesignSystem.Spacing.sm)

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
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 14))
                                .foregroundStyle(DesignSystem.Colors.accent)
                            Text("Mental Rule")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }

                        Text("\"\(rule)\"")
                            .font(DesignSystem.Typography.headline)
                            .italic()
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding(DesignSystem.Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .fill(DesignSystem.Colors.accent.opacity(0.1))
                            )
                    }
                }

                // Note section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "note.text")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.accent)
                        Text("Session Note")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    TextField("Add a note...", text: $note, axis: .vertical)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(DesignSystem.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(DesignSystem.Colors.cardBackgroundLight)
                        )
                        .lineLimit(3...6)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.top, DesignSystem.Spacing.lg)
        }
    }

    private func detailSection(icon: String, title: String, content: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(content)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.callout)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(DesignSystem.Colors.cardBackgroundLight)
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
            // Base gradient using accent colors
            LinearGradient(
                colors: [
                    DesignSystem.Colors.accent.opacity(0.7),
                    DesignSystem.Colors.accentMuted.opacity(0.8),
                    DesignSystem.Colors.focus.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Swirl effect using radial gradients
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            DesignSystem.Colors.accent.opacity(0.6),
                            DesignSystem.Colors.accentMuted.opacity(0.3),
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
                            DesignSystem.Colors.focus.opacity(0.5),
                            DesignSystem.Colors.deep.opacity(0.3),
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
                            DesignSystem.Colors.accent.opacity(0.4),
                            DesignSystem.Colors.accentMuted.opacity(0.2)
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
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
