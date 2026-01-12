import SwiftUI

/// Control for adjusting total project time in hours
struct TotalTimeControl: View {
    @Binding var totalHours: Int

    private let minHours: Int = 5
    private let maxHours: Int = 200
    private let step: Int = 5

    var body: some View {
        VStack(spacing: 12) {
            Text("Total Project Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Button {
                    totalHours = max(minHours, totalHours - step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.purple)
                }
                .disabled(totalHours <= minHours)

                Text("\(totalHours) hours")
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(width: 120)
                    .monospacedDigit()

                Button {
                    totalHours = min(maxHours, totalHours + step)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.purple)
                }
                .disabled(totalHours >= maxHours)
            }

            Slider(
                value: Binding(
                    get: { Double(totalHours) },
                    set: { totalHours = Int($0) }
                ),
                in: Double(minHours)...Double(maxHours),
                step: Double(step)
            )
            .tint(.purple)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TotalTimeControl(totalHours: .constant(40))
        .padding()
}
