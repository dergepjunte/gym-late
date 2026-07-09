import SwiftUI

/// Liquid-glass notification pill that appears above the nav bar for
/// passive opening-sequence prompts (Wrapped, Daily Hype, Geo check-in).
///
/// Layout (matches attached mock):
///   [ yellow circle glyph ] [ bold title      ] [×]
///                           [ secondary subtitle ]
///
/// Tapping the pill body calls `onTap`; tapping × calls `onDismiss`.
struct NotificationBubbleView: View {
    let bubble: BubbleNotification
    let onTap: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            // Yellow circle with glyph
            Text(bubble.glyph)
                .font(.system(size: 22))
                .frame(width: 50, height: 50)
                .background(
                    Circle().fill(LinearGradient(
                        colors: Theme.accentGradient,
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                )

            // Text stack
            VStack(alignment: .leading, spacing: 2) {
                Text(bubble.title)
                    .font(Theme.heading(15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(bubble.subtitle)
                    .font(Theme.body(13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(.systemFill)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bubbleBackground)
        .onTapGesture { onTap() }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(
            UIAccessibility.isReduceMotionEnabled
                ? .easeInOut(duration: 0.18)
                : .spring(response: 0.42, dampingFraction: 0.76),
            value: appeared
        )
        .onAppear { appeared = true }
    }

    private var bubbleBackground: some View {
        let g = Theme.Glass.tokens(for: scheme)
        return Group {
            if #available(iOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: .capsule)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay(
            Capsule().fill(LinearGradient(
                stops: [.init(color: g.sheen, location: 0),
                        .init(color: .clear, location: 0.45)],
                startPoint: .topLeading, endPoint: .bottom))
            .allowsHitTesting(false)
        )
        .overlay(
            Capsule().strokeBorder(LinearGradient(
                colors: [g.borderTop, g.border],
                startPoint: .top, endPoint: .bottom), lineWidth: 1)
            .allowsHitTesting(false)
        )
        .shadow(color: g.shadow, radius: 12, x: 0, y: 6)
    }
}

/// Small hint chip shown below the nav bar after a bubble is dismissed.
struct ReplayHintChip: View {
    let hint: AppState.ReplayHint
    let onTap: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: onTap) {
            Text(hint == .recap ? K.L.replayHintRecap : K.L.replayHintCheckin)
                .font(Theme.body(12, .semibold))
                .foregroundColor(K.amberText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(K.accent.opacity(0.18))
                        .overlay(Capsule().strokeBorder(K.accentDeep.opacity(0.3), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .animation(.easeInOut(duration: 0.22), value: appeared)
        .onAppear { appeared = true }
    }
}
