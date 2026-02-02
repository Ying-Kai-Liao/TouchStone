import SwiftUI

// MARK: - Day Timeline Event Card

/// A positioned event card for the visual timeline.
/// Supports two variants:
/// - Stone (fixed events): solid cards with accent background and shadow
/// - Water (suggested sessions): dashed border, muted background
struct DayTimelineEventCard: View {
    enum CardVariant {
        case stone(StoneEvent)
        case water(SuggestedSession)
    }

    let variant: CardVariant
    let isCompact: Bool
    let onTap: () -> Void

    private var title: String {
        switch variant {
        case .stone(let stone):
            return stone.title
        case .water(let session):
            return session.project.title
        }
    }

    private var timeRangeString: String {
        switch variant {
        case .stone(let stone):
            return stone.timeRangeString
        case .water(let session):
            return session.timeRangeString
        }
    }

    private var durationMinutes: Int {
        switch variant {
        case .stone(let stone):
            return stone.durationMinutes
        case .water(let session):
            return session.suggestedMinutes
        }
    }

    private var durationString: String {
        if durationMinutes >= 60 {
            let hours = durationMinutes / 60
            let mins = durationMinutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
        return "\(durationMinutes)m"
    }

    private var isStone: Bool {
        if case .stone = variant { return true }
        return false
    }

    var body: some View {
        Button(action: {
            HapticService.selection()
            onTap()
        }) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cardContent: some View {
        if isCompact {
            compactLayout
        } else {
            standardLayout
        }
    }

    private var standardLayout: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.Typography.body)
                .fontWeight(.medium)
                .foregroundStyle(isStone ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .lineLimit(2)

            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(timeRangeString)
                    .font(DesignSystem.Typography.caption)

                Text("(\(durationString))")
                    .font(DesignSystem.Typography.caption)
            }
            .foregroundStyle(isStone ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignSystem.Spacing.sm)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small, style: .continuous))
        .overlay(cardBorder)
        .shadow(color: isStone ? Color.black.opacity(0.08) : .clear, radius: 4, y: 2)
    }

    private var compactLayout: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(isStone ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(durationString)
                .font(.system(size: 10))
                .foregroundStyle(isStone ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small, style: .continuous))
        .overlay(cardBorder)
        .shadow(color: isStone ? Color.black.opacity(0.06) : .clear, radius: 2, y: 1)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if isStone {
            DesignSystem.Colors.accent.opacity(0.15)
        } else {
            DesignSystem.Colors.cardBackground.opacity(0.6)
        }
    }

    @ViewBuilder
    private var cardBorder: some View {
        if isStone {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small, style: .continuous)
                .strokeBorder(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(DesignSystem.Colors.textTertiary.opacity(0.5))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Stone card preview
        DayTimelineEventCard(
            variant: .stone(StoneEvent(
                title: "Morning Meeting",
                startHour: 9,
                startMinute: 0,
                endHour: 10,
                endMinute: 30
            )),
            isCompact: false,
            onTap: {}
        )
        .frame(height: 90)

        // Compact stone card
        DayTimelineEventCard(
            variant: .stone(StoneEvent(
                title: "Quick Call",
                startHour: 11,
                startMinute: 0,
                endHour: 11,
                endMinute: 30
            )),
            isCompact: true,
            onTap: {}
        )
        .frame(height: 30)
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
