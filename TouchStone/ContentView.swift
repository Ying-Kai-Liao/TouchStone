import SwiftUI
import SwiftData

struct ContentView: View {
    private var prefs = UserPreferences.shared
    @State private var showingAskSheet = false
    @State private var showingVoiceSheet = false

    var body: some View {
        ZStack {
            // Noisy gradient background
            NoisyGradientBackground()

            TabView {
                TodayFlowView()
                    .tabItem {
                        Label("Flow", systemImage: "drop.fill")
                    }

                CalendarView()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }

                ProjectsListView()
                    .tabItem {
                        Label("Plan", systemImage: "square.grid.2x2")
                    }

                MeView()
                    .tabItem {
                        Label("Me", systemImage: "person")
                    }
            }
            .tint(prefs.accentColor)

            // Floating magic button (bottom-left)
            FloatingMagicButton(
                onAsk: { showingAskSheet = true },
                onVoice: { showingVoiceSheet = true }
            )
        }
        .sheet(isPresented: $showingAskSheet) {
            UnifiedInputView()
        }
        .sheet(isPresented: $showingVoiceSheet) {
            QuickVoiceSheet { _ in
                showingVoiceSheet = false
                // Small delay then open ask sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingAskSheet = true
                }
            }
        }
    }
}

// MARK: - Quick Voice Sheet

/// A streamlined voice input sheet triggered from the magic button
struct QuickVoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var speechRecognizer = SpeechRecognizer()

    let onTranscribe: (String) -> Void

    private var isRecording: Bool {
        speechRecognizer.state == .recording
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Drag indicator
            Capsule()
                .fill(DesignSystem.Colors.textTertiary.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            Spacer()

            // Listening orb
            ZStack {
                // Outer pulse
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(isRecording ? 0.2 : 0.05))
                    .frame(width: 160, height: 160)
                    .scaleEffect(isRecording ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)

                // Inner circle
                Circle()
                    .fill(DesignSystem.Colors.cardBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 20)

                // Mic icon
                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(isRecording ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .onTapGesture {
                if isRecording {
                    speechRecognizer.stopRecording()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !speechRecognizer.transcript.isEmpty {
                            onTranscribe(speechRecognizer.transcript)
                            dismiss()
                        }
                    }
                } else {
                    try? speechRecognizer.startRecording()
                }
            }

            // Transcript
            if !speechRecognizer.transcript.isEmpty {
                Text(speechRecognizer.transcript)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .lineLimit(3)
            } else {
                Text(isRecording ? "Listening..." : "Tap to speak")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Cancel button
            Button {
                speechRecognizer.reset()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .task {
            _ = await speechRecognizer.requestAuthorization()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, ProjectPhase.self, Milestone.self, StoneEvent.self, TouchLog.self, FocusSession.self], inMemory: true)
}
