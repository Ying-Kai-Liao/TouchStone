import SwiftUI

/// A celebratory confetti burst that appears when a touch is logged
struct TouchCelebrationView: View {
    let isShowing: Bool
    let accentColor: Color

    @State private var particles: [ConfettiParticle] = []

    private let particleCount = 20

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onChange(of: isShowing) { _, showing in
                if showing {
                    spawnParticles(in: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func spawnParticles(in size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2

        // Create particles with random properties
        var newParticles: [ConfettiParticle] = []

        for i in 0..<particleCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let velocity = Double.random(in: 100...250)
            let particleSize = CGFloat.random(in: 4...10)

            let colors: [Color] = [
                accentColor,
                accentColor.opacity(0.7),
                DesignSystem.Colors.success,
                DesignSystem.Colors.warning,
                .white.opacity(0.8)
            ]

            newParticles.append(ConfettiParticle(
                id: i,
                position: CGPoint(x: centerX, y: centerY),
                velocity: velocity,
                angle: angle,
                size: particleSize,
                color: colors.randomElement() ?? accentColor,
                opacity: 1.0
            ))
        }

        particles = newParticles

        // Animate particles outward
        withAnimation(.easeOut(duration: 0.6)) {
            particles = particles.map { particle in
                var updated = particle
                let dx = cos(particle.angle) * particle.velocity
                let dy = sin(particle.angle) * particle.velocity
                updated.position = CGPoint(
                    x: particle.position.x + dx,
                    y: particle.position.y + dy - 50 // Bias upward
                )
                updated.opacity = 0
                return updated
            }
        }

        // Clear particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            particles = []
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id: Int
    var position: CGPoint
    let velocity: Double
    let angle: Double
    let size: CGFloat
    let color: Color
    var opacity: Double
}

// MARK: - Simpler Glow Celebration

/// A quick glow/pulse effect for touch celebration
struct TouchGlowCelebration: View {
    let isShowing: Bool
    let color: Color

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.6), color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 150
                )
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: isShowing) { _, showing in
                if showing {
                    triggerGlow()
                }
            }
            .allowsHitTesting(false)
    }

    private func triggerGlow() {
        scale = 0.5
        opacity = 0.8

        withAnimation(.easeOut(duration: 0.4)) {
            scale = 2.0
            opacity = 0
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        TouchCelebrationView(
            isShowing: true,
            accentColor: DesignSystem.Colors.accent
        )
    }
}
