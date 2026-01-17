import SwiftUI

// MARK: - Swipe to Delete Row

/// A reusable swipe-to-delete row component with smooth animations.
/// Swipe left to reveal delete button, tap delete for animated removal.
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @GestureState private var dragOffset: CGFloat = 0
    @State private var currentOffset: CGFloat = 0
    @State private var isDeleting = false

    private let deleteButtonWidth: CGFloat = 70

    private var totalOffset: CGFloat {
        if isDeleting {
            return -500 // Slide far off screen
        }
        let raw = currentOffset + dragOffset
        // Rubber band effect when swiping right from closed state
        if raw > 0 {
            return raw * 0.3
        }
        // Rubber band effect when over-swiping left
        if raw < -deleteButtonWidth - 20 {
            let overshoot = raw + deleteButtonWidth + 20
            return -deleteButtonWidth - 20 + overshoot * 0.3
        }
        return raw
    }

    private var isOpen: Bool {
        currentOffset < -10
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button - always present but clipped
            HStack(spacing: 0) {
                Spacer()
                Button(action: {
                    // Animate row sliding out
                    withAnimation(.easeIn(duration: 0.25)) {
                        isDeleting = true
                    }
                    // Call onDelete after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: deleteButtonWidth, height: .infinity)
                }
                .frame(width: isDeleting ? 500 : max(0, -totalOffset), height: 70)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: isDeleting ? 0 : 12))
            }

            // Content
            content()
                .offset(x: totalOffset)
                .opacity(isDeleting ? 0 : 1)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .updating($dragOffset) { value, state, _ in
                            if !isDeleting {
                                state = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if isDeleting { return }
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            let projected = currentOffset + value.translation.width + velocity * 0.5

                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                if projected < -deleteButtonWidth / 2 {
                                    // Snap open
                                    currentOffset = -deleteButtonWidth
                                } else {
                                    // Snap closed
                                    currentOffset = 0
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            if isOpen && !isDeleting {
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                    currentOffset = 0
                                }
                            }
                        }
                )
        }
        .frame(height: isDeleting ? 0 : nil)
        .clipped()
        .animation(.easeIn(duration: 0.25), value: isDeleting)
    }
}
