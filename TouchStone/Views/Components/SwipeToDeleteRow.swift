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
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Delete button - fixed position, revealed by content sliding
                HStack {
                    Spacer()
                    Button(action: performDelete) {
                        Image(systemName: "trash.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: deleteButtonWidth, height: geometry.size.height)
                    }
                    .frame(width: deleteButtonWidth)
                    .background(Color.red)
                }

                // Content slides to reveal delete button
                content()
                    .frame(width: geometry.size.width)
                    .background(Color(.systemBackground))
                    .offset(x: totalOffset)
            }
        }
        .frame(height: isDeleting ? 0 : nil)
        .clipped()
        .opacity(isDeleting ? 0 : 1)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 8)
                .updating($dragOffset) { value, state, _ in
                    if !isDeleting {
                        state = value.translation.width
                    }
                }
                .onEnded { value in
                    if isDeleting { return }
                    let velocity = value.predictedEndTranslation.width - value.translation.width
                    let projected = currentOffset + value.translation.width + velocity * 0.3

                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                        if projected < -deleteButtonWidth / 2 {
                            currentOffset = -deleteButtonWidth
                        } else {
                            currentOffset = 0
                        }
                    }
                }
        )
        .onTapGesture {
            if isOpen && !isDeleting {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    currentOffset = 0
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: isDeleting)
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
