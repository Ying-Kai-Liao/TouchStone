import SwiftUI

// MARK: - Swipe to Delete Row

/// A reusable swipe-to-delete row component with smooth animations.
/// Swipe left to reveal delete button, tap delete for animated removal.
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    // Use @State instead of @GestureState to prevent flashing on gesture end
    @State private var dragOffset: CGFloat = 0
    @State private var currentOffset: CGFloat = 0
    @State private var isDeleting = false

    private let deleteButtonWidth: CGFloat = 70

    private var totalOffset: CGFloat {
        if isDeleting {
            return -500
        }
        let raw = currentOffset + dragOffset
        if raw > 0 {
            return raw * 0.3
        }
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
            // Delete button - at back of ZStack
            deleteButton
                .opacity(totalOffset < 0 ? 1 : 0)

            // Content - at front, fills width, with background that slides
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .offset(x: totalOffset)
        }
        .clipped()
        .frame(height: isDeleting ? 0 : nil)
        .opacity(isDeleting ? 0 : 1)
        .contentShape(Rectangle())
        .highPriorityGesture(swipeGesture)
        .onTapGesture {
            if isOpen && !isDeleting {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    currentOffset = 0
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: isDeleting)
    }

    private var deleteButton: some View {
        Button(action: performDelete) {
            VStack {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Delete")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .frame(width: deleteButtonWidth)
            .frame(maxHeight: .infinity)
            .background(Color.red)
        }
        .buttonStyle(.plain)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !isDeleting {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                if isDeleting { return }
                let finalOffset = currentOffset + dragOffset
                let velocity = value.predictedEndTranslation.width - value.translation.width
                let projected = finalOffset + velocity * 0.3

                // Animate both dragOffset reset AND currentOffset change together
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    dragOffset = 0  // Reset with animation (fixes flashing)
                    if projected < -deleteButtonWidth / 2 {
                        currentOffset = -deleteButtonWidth
                    } else {
                        currentOffset = 0
                    }
                }
            }
    }

    private func performDelete() {
        withAnimation(.easeOut(duration: 0.2)) {
            isDeleting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDelete()
        }
    }
}
