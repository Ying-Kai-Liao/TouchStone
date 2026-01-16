import SwiftUI

// MARK: - Work Today Prompt View

/// A bottom overlay component that asks "Do you want to work today?"
/// This is the gate that starts the day - recording when the user begins.
/// The allocation shown is just a suggestion; this prompt enables touch tracking.
struct WorkTodayPromptView: View {
    let onConfirmWork: () -> Void
    let onDeclineWork: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Do you want to work today?")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                // Decline button
                Button(action: onDeclineWork) {
                    Text("Not today")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }

                // Confirm button
                Button(action: onConfirmWork) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("Let's go")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(UserPreferences.shared.accentColor)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(uiColor: UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 0.95)))
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(uiColor: UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1.0))
            .ignoresSafeArea()

        VStack {
            Spacer()
            WorkTodayPromptView(
                onConfirmWork: { print("Work confirmed") },
                onDeclineWork: { print("Work declined") }
            )
        }
    }
    .preferredColorScheme(.dark)
}
