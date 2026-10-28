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
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LinearGradient(
                        colors: Theme.accentGradient,
                        startPoint: .top, endPoint: .bottom))
                )

            // Text stack
            VStack(alignment: .leading, spacing: 2) {
                Text(bubble.title.uppercased())
                    .font(Theme.heading(17))
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
        // v0.3 "Iron": steel bar with a yellow load-stripe on the left.
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(LinearGradient(colors: [K.iron2, K.iron1], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, style: .continuous)
                    .fill(K.accent).frame(width: 5)
            }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(K.accent.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 14, x: 0, y: 8)
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
