import SwiftUI

// MARK: - Magic Button Mode

enum MagicButtonMode: CaseIterable {
    case ask      // Sparkles - open chat
    case voice    // Mic - voice input

    var icon: String {
        switch self {
        case .ask: return "sparkles"
        case .voice: return "mic.fill"
        }
    }

    var next: MagicButtonMode {
        switch self {
        case .ask: return .voice
        case .voice: return .ask
        }
    }
}

// MARK: - Magic Ask Button

/// A luminous floating orb button that serves as the AI assistant entry point.
/// Features layered glass effects, subtle particle shimmer, and a gentle breathing animation.
/// Tap to activate, long-press to switch between chat and voice modes.
struct MagicAskButton: View {
    let onAsk: () -> Void
    let onVoice: () -> Void

    @State private var mode: MagicButtonMode = .ask
    @State private var isPressed = false
    @State private var breathePhase: CGFloat = 0
    @State private var shimmerOffset: CGFloat = 0
    @State private var particleRotation: Double = 0
    @State private var iconRotation: Double = 0
    @State private var showModeHint = false

    private var accentColor: Color { UserPreferences.shared.accentColor }

    // Adaptive colors for light/dark mode
    private var isDarkMode: Bool {
        switch UserPreferences.shared.appearanceMode {
        case .dark: return true
        case .light: return false
        case .system: return true
        }
    }

    // Button dimensions
    private let buttonSize: CGFloat = 56
    private let glowRadius: CGFloat = 60

    // MARK: - Adaptive Colors

    private var glowOpacity: (inner: Double, mid: Double, outer: Double) {
        isDarkMode
            ? (0.35, 0.15, 0.05)
            : (0.25, 0.12, 0.04)
    }

    private var buttonBackground: Color {
        isDarkMode
            ? DesignSystem.Colors.cardBackground
            : Color.white
    }

    private var highlightColor: Color {
        isDarkMode
            ? Color.white.opacity(0.25)
            : Color.white.opacity(0.8)
    }

    private var shadowColor: Color {
        isDarkMode
            ? Color.black.opacity(0.3)
            : Color.black.opacity(0.15)
    }

    private var iconPrimaryColor: Color {
        isDarkMode
            ? Color.white.opacity(0.95)
            : accentColor
    }

    private var iconSecondaryColor: Color {
        isDarkMode
            ? accentColor.opacity(0.9)
            : accentColor.opacity(0.6)
    }

    var body: some View {
        ZStack {
            // Mode hint label (appears on mode switch)
            if showModeHint {
                Text(mode == .ask ? "Chat" : "Voice")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.9))
                    )
                    .offset(x: 50, y: -10)
                    .transition(.scale.combined(with: .opacity))
            }

            Button {
                // Tap action based on current mode
                switch mode {
                case .ask: onAsk()
                case .voice: onVoice()
                }
            } label: {
                ZStack {
                    // Layer 1: Outer atmospheric glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    accentColor.opacity(glowOpacity.inner),
                                    accentColor.opacity(glowOpacity.mid),
                                    accentColor.opacity(glowOpacity.outer),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: buttonSize * 0.3,
                                endRadius: glowRadius
                            )
                        )
                        .frame(width: glowRadius * 2, height: glowRadius * 2)
                        .scaleEffect(1 + breathePhase * 0.08)
                        .opacity(0.8 + breathePhase * 0.2)

                    // Layer 2: Shimmer ring (rotating particles)
                    shimmerRing
                        .frame(width: buttonSize + 20, height: buttonSize + 20)
                        .rotationEffect(.degrees(particleRotation))

                    // Layer 3: Glass morphism base
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    buttonBackground.opacity(0.95),
                                    buttonBackground.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: buttonSize, height: buttonSize)
                        .overlay(
                            // Inner glass highlight
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            highlightColor,
                                            highlightColor.opacity(0.3),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .overlay(
                            // Accent border ring (more visible on light mode)
                            Circle()
                                .stroke(
                                    accentColor.opacity(isDarkMode ? 0.2 : 0.3),
                                    lineWidth: 1
                                )
                                .padding(1)
                        )
                        .shadow(color: shadowColor, radius: 12, x: 0, y: 4)
                        .shadow(color: accentColor.opacity(isDarkMode ? 0.2 : 0.25), radius: 8, x: 0, y: 0)

                    // Layer 4: Accent color inner glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    accentColor.opacity((isDarkMode ? 0.4 : 0.3) + breathePhase * 0.15),
                                    accentColor.opacity(isDarkMode ? 0.1 : 0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: buttonSize * 0.45
                            )
                        )
                        .frame(width: buttonSize - 8, height: buttonSize - 8)

                    // Layer 5: Icon with shimmer and rotation transition
                    ZStack {
                        Image(systemName: mode.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        iconPrimaryColor,
                                        iconSecondaryColor
                                    ],
                                    startPoint: UnitPoint(x: shimmerOffset, y: 0),
                                    endPoint: UnitPoint(x: shimmerOffset + 0.5, y: 1)
                                )
                            )
                            .shadow(color: accentColor.opacity(isDarkMode ? 0.5 : 0.3), radius: 4, x: 0, y: 0)
                            .rotationEffect(.degrees(iconRotation))
                            .id(mode) // Force view recreation for smooth transition
                    }
                    .scaleEffect(isPressed ? 0.85 : 1.0)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .onEnded { _ in
                        switchMode()
                    }
            )
            .onAppear {
                startAnimations()
            }
        }
    }

    // MARK: - Mode Switching

    private func switchMode() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Animate icon rotation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            iconRotation += 360
            mode = mode.next
        }

        // Show mode hint
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showModeHint = true
        }

        // Hide hint after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showModeHint = false
            }
        }
    }

    // MARK: - Shimmer Ring

    private var shimmerRing: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 2

            // Draw small particles around the ring
            for i in 0..<8 {
                let angle = (Double(i) / 8.0) * 2 * .pi
                let particleX = center.x + cos(angle) * radius
                let particleY = center.y + sin(angle) * radius

                // Vary particle opacity based on position for shimmer effect
                // Higher base opacity for light mode visibility
                let shimmerPhase = (shimmerOffset + CGFloat(i) / 8.0).truncatingRemainder(dividingBy: 1.0)
                let baseOpacity = isDarkMode ? 0.2 : 0.4
                let maxOpacity = isDarkMode ? 0.6 : 0.8
                let opacity = baseOpacity + shimmerPhase * maxOpacity

                let particleSize: CGFloat = 2 + shimmerPhase * 2

                let rect = CGRect(
                    x: particleX - particleSize / 2,
                    y: particleY - particleSize / 2,
                    width: particleSize,
                    height: particleSize
                )

                context.fill(
                    Circle().path(in: rect),
                    with: .color(accentColor.opacity(opacity))
                )
            }
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Breathing animation - slow, organic pulse
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            breathePhase = 1.0
        }

        // Shimmer animation - continuous sweep
        withAnimation(
            .linear(duration: 4.0)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 1.0
        }

        // Particle rotation - very slow rotation
        withAnimation(
            .linear(duration: 20.0)
            .repeatForever(autoreverses: false)
        ) {
            particleRotation = 360
        }
    }
}

// MARK: - Floating Button Container

/// Positions the magic button in the bottom-left corner above the tab bar
struct FloatingMagicButton: View {
    let onAsk: () -> Void
    let onVoice: () -> Void

    // Tab bar height is ~49pt + we want some padding
    private let tabBarOffset: CGFloat = 60

    var body: some View {
        VStack {
            Spacer()
            HStack {
                MagicAskButton(onAsk: onAsk, onVoice: onVoice)
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.bottom, tabBarOffset)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        NoisyGradientBackground()

        FloatingMagicButton(
            onAsk: { print("Ask tapped") },
            onVoice: { print("Voice tapped") }
        )
    }
}
